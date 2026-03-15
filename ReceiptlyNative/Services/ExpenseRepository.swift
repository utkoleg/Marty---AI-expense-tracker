import Foundation

protocol ExpenseRepository {
    func load() -> [Expense]
    func save(_ expenses: [Expense]) throws
}

let liveDocumentsURL: URL = {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent("receiptly_v8.json")
}()

final class LocalExpenseRepository: ExpenseRepository {
    private let fileURL: URL
    private let userDefaults: UserDefaults
    private let legacyKey: String

    init(
        fileURL: URL = liveDocumentsURL,
        userDefaults: UserDefaults = .standard,
        legacyKey: String = "receiptly_v8"
    ) {
        self.fileURL = fileURL
        self.userDefaults = userDefaults
        self.legacyKey = legacyKey
    }

    func load() -> [Expense] {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            return decoded
        }

        if let raw = userDefaults.string(forKey: legacyKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            return decoded
        }

        return []
    }

    func save(_ expenses: [Expense]) throws {
        let data = try JSONEncoder().encode(expenses)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}

final class InMemoryExpenseRepository: ExpenseRepository {
    private var storedExpenses: [Expense]

    init(initialExpenses: [Expense] = []) {
        storedExpenses = initialExpenses
    }

    func load() -> [Expense] {
        storedExpenses
    }

    func save(_ expenses: [Expense]) throws {
        storedExpenses = expenses
    }
}
