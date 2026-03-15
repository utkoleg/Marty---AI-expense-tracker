import Foundation
import Supabase

protocol ExpenseRepository {
    var cachedExpenses: [Expense] { get }
    func fetchExpenses() async throws -> [Expense]
    func insert(_ expense: Expense) async throws
    func update(_ expense: Expense) async throws
    func delete(id: String) async throws
    func deleteAll() async throws
}

protocol ExpenseRemoteStore {
    func fetchRows(for userID: String) async throws -> [ExpenseRow]
    func upsert(_ rows: [ExpenseRow]) async throws
    func deleteExpense(id: String, userID: String) async throws
    func deleteAllExpenses(for userID: String) async throws
}

enum ExpenseRepositoryError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return loc(
                "Sign in before syncing expenses.",
                "Войди в аккаунт перед синхронизацией расходов."
            )
        }
    }
}

private func makeExpenseDocumentsURL(fileName: String) -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent(fileName)
}

let defaultExpenseDocumentsURL = makeExpenseDocumentsURL(fileName: "receiptly_v8.json")

func userScopedExpenseDocumentsURL(for userID: String) -> URL {
    let sanitizedUserID = userID.replacingOccurrences(of: "/", with: "_")
    return makeExpenseDocumentsURL(fileName: "receiptly_cache_\(sanitizedUserID).json")
}

final class LocalExpenseRepository: ExpenseRepository {
    private let fileURL: URL
    private let userDefaults: UserDefaults
    private let legacyKey: String

    init(
        fileURL: URL = defaultExpenseDocumentsURL,
        userDefaults: UserDefaults = .standard,
        legacyKey: String = "receiptly_v8"
    ) {
        self.fileURL = fileURL
        self.userDefaults = userDefaults
        self.legacyKey = legacyKey
    }

    var cachedExpenses: [Expense] {
        readStoredRows().map { $0.asExpense() }
    }

    func fetchExpenses() async throws -> [Expense] {
        cachedExpenses
    }

    func insert(_ expense: Expense) async throws {
        var rows = readStoredRows()
        let row = ExpenseRow(expense: expense)

        rows.removeAll { $0.id == row.id }
        rows.insert(row, at: 0)

        try persist(rows)
    }

    func update(_ expense: Expense) async throws {
        var rows = readStoredRows()
        let row = ExpenseRow(expense: expense)

        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[index] = row

        try persist(rows)
    }

    func delete(id: String) async throws {
        var rows = readStoredRows()
        rows.removeAll { $0.id == id }
        try persist(rows)
    }

    func deleteAll() async throws {
        try persist([])
    }

    func replaceAll(with expenses: [Expense]) throws {
        try persist(expenses.map { ExpenseRow(expense: $0) })
    }

    private func readStoredRows() -> [ExpenseRow] {
        if let rows = decodeRows(from: try? Data(contentsOf: fileURL)) {
            return rows
        }

        if let rows = decodeRows(fromLegacyValue: userDefaults.string(forKey: legacyKey)) {
            return rows
        }

        return []
    }

    private func decodeRows(from data: Data?) -> [ExpenseRow]? {
        guard let data else { return nil }

        if let decodedRows = try? JSONDecoder().decode([ExpenseRow].self, from: data) {
            return decodedRows
        }

        if let legacyExpenses = try? JSONDecoder().decode([Expense].self, from: data) {
            return legacyExpenses.map { ExpenseRow(expense: $0) }
        }

        return nil
    }

    private func decodeRows(fromLegacyValue rawValue: String?) -> [ExpenseRow]? {
        guard let rawValue, let data = rawValue.data(using: .utf8) else { return nil }
        return decodeRows(from: data)
    }

    private func persist(_ rows: [ExpenseRow]) throws {
        let data = try JSONEncoder().encode(rows)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}

final class SupabaseExpenseRemoteStore: ExpenseRemoteStore {
    private let supabase: SupabaseClient
    private let tableName: String

    init(
        supabase: SupabaseClient,
        tableName: String = "expenses"
    ) {
        self.supabase = supabase
        self.tableName = tableName
    }

    func fetchRows(for userID: String) async throws -> [ExpenseRow] {
        try await supabase
            .from(tableName)
            .select()
            .eq("user_id", value: userID)
            .order("added_at", ascending: false)
            .execute()
            .value
    }

    func upsert(_ rows: [ExpenseRow]) async throws {
        guard !rows.isEmpty else { return }

        try await supabase
            .from(tableName)
            .upsert(rows, onConflict: "id", returning: .minimal)
            .execute()
    }

    func deleteExpense(id: String, userID: String) async throws {
        try await supabase
            .from(tableName)
            .delete(returning: .minimal)
            .eq("id", value: id)
            .eq("user_id", value: userID)
            .execute()
    }

    func deleteAllExpenses(for userID: String) async throws {
        try await supabase
            .from(tableName)
            .delete(returning: .minimal)
            .eq("user_id", value: userID)
            .execute()
    }
}

final class SupabaseExpenseRepository: ExpenseRepository {
    private let userID: String
    private let remoteStore: any ExpenseRemoteStore
    private let cacheRepository: LocalExpenseRepository
    private let migrationSourceRepository: LocalExpenseRepository
    private let clearsMigrationSourceAfterSync: Bool

    init(
        userID: String,
        remoteStore: any ExpenseRemoteStore,
        cacheRepository: LocalExpenseRepository? = nil,
        migrationSourceRepository: LocalExpenseRepository = LocalExpenseRepository(),
        clearsMigrationSourceAfterSync: Bool = true
    ) {
        self.userID = userID
        self.remoteStore = remoteStore
        self.cacheRepository = cacheRepository ?? LocalExpenseRepository(
            fileURL: userScopedExpenseDocumentsURL(for: userID),
            legacyKey: "receiptly_cache_\(userID)"
        )
        self.migrationSourceRepository = migrationSourceRepository
        self.clearsMigrationSourceAfterSync = clearsMigrationSourceAfterSync
        promoteLegacyCacheIfNeeded()
    }

    var cachedExpenses: [Expense] {
        cacheRepository.cachedExpenses
    }

    func fetchExpenses() async throws -> [Expense] {
        let remoteRows = try await remoteStore.fetchRows(for: userID)

        if remoteRows.isEmpty {
            let bootstrapExpenses = bootstrapExpenses()

            guard !bootstrapExpenses.isEmpty else {
                try cacheRepository.replaceAll(with: [])
                return []
            }

            try await remoteStore.upsert(
                bootstrapExpenses.map { ExpenseRow(expense: $0, userID: userID) }
            )
            try cacheRepository.replaceAll(with: bootstrapExpenses)
            try await clearMigrationSourceIfNeeded()
            return bootstrapExpenses
        }

        let expenses = remoteRows.map { $0.asExpense() }
        try cacheRepository.replaceAll(with: expenses)
        try await clearMigrationSourceIfNeeded()
        return expenses
    }

    func insert(_ expense: Expense) async throws {
        try await cacheRepository.insert(expense)
        try await remoteStore.upsert([ExpenseRow(expense: expense, userID: userID)])
    }

    func update(_ expense: Expense) async throws {
        try await cacheRepository.update(expense)
        try await remoteStore.upsert([ExpenseRow(expense: expense, userID: userID)])
    }

    func delete(id: String) async throws {
        try await cacheRepository.delete(id: id)
        try await remoteStore.deleteExpense(id: id, userID: userID)
    }

    func deleteAll() async throws {
        try await cacheRepository.deleteAll()
        try await remoteStore.deleteAllExpenses(for: userID)
    }

    private func bootstrapExpenses() -> [Expense] {
        let cachedExpenses = cacheRepository.cachedExpenses
        if !cachedExpenses.isEmpty {
            return cachedExpenses
        }

        return migrationSourceRepository.cachedExpenses
    }

    private func clearMigrationSourceIfNeeded() async throws {
        guard clearsMigrationSourceAfterSync else { return }
        try await migrationSourceRepository.deleteAll()
    }

    private func promoteLegacyCacheIfNeeded() {
        guard cacheRepository.cachedExpenses.isEmpty else { return }

        let legacyExpenses = migrationSourceRepository.cachedExpenses
        guard !legacyExpenses.isEmpty else { return }

        try? cacheRepository.replaceAll(with: legacyExpenses)

        if clearsMigrationSourceAfterSync {
            try? migrationSourceRepository.replaceAll(with: [])
        }
    }
}

final class InMemoryExpenseRepository: ExpenseRepository {
    private var storedExpenses: [Expense]

    init(initialExpenses: [Expense] = []) {
        storedExpenses = initialExpenses
    }

    var cachedExpenses: [Expense] {
        storedExpenses
    }

    func fetchExpenses() async throws -> [Expense] {
        storedExpenses
    }

    func insert(_ expense: Expense) async throws {
        storedExpenses.removeAll { $0.id == expense.id }
        storedExpenses.insert(expense, at: 0)
    }

    func update(_ expense: Expense) async throws {
        guard let index = storedExpenses.firstIndex(where: { $0.id == expense.id }) else { return }
        storedExpenses[index] = expense
    }

    func delete(id: String) async throws {
        storedExpenses.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        storedExpenses = []
    }
}
