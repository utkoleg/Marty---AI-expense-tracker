import XCTest
@testable import ReceiptlyNative

final class LocalExpenseRepositoryTests: XCTestCase {
    func testCachedExpensesReadsSavedJSONFile() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        let expenses = [
            makeExpense(
                id: "expense-1",
                merchant: "Trader Joe's",
                total: 42.35,
                items: [
                    makeExpenseItem(name: "Bananas", quantity: 2, price: 2.35),
                    makeExpenseItem(name: "Bread", quantity: 1, price: 4.50),
                ]
            ),
        ]
        let data = try JSONEncoder().encode(expenses)
        try data.write(to: fileURL, options: [.atomic])

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        XCTAssertEqual(snapshot(repository.cachedExpenses), snapshot(expenses))
    }

    func testCachedExpensesFallsBackToLegacyUserDefaults() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        let expenses = [
            makeExpense(id: "expense-legacy", merchant: "CVS", total: 8.48),
        ]
        let data = try JSONEncoder().encode(expenses)
        defaults.set(String(decoding: data, as: UTF8.self), forKey: "receiptly_v8")

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        XCTAssertEqual(snapshot(repository.cachedExpenses), snapshot(expenses))
    }

    func testCachedExpensesReturnsEmptyWhenFileAndLegacyAreInvalid() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        try Data("not-json".utf8).write(to: fileURL, options: [.atomic])
        defaults.set("still-not-json", forKey: "receiptly_v8")

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        XCTAssertEqual(repository.cachedExpenses, [])
    }

    func testInsertUpdateDeleteRoundTripWithoutChangingExpenseContent() async throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        let original = makeExpense(
            id: "expense-roundtrip",
            merchant: "Target",
            total: 21.97,
            category: "Haircare",
            items: [
                makeExpenseItem(name: "Shampoo", quantity: 1, price: 12.98),
                makeExpenseItem(name: "Conditioner", quantity: 1, price: 8.99),
            ],
            groups: [
                makeExpenseGroup(
                    category: "Haircare",
                    items: [
                        makeExpenseItem(name: "Shampoo", quantity: 1, price: 12.98),
                        makeExpenseItem(name: "Conditioner", quantity: 1, price: 8.99),
                    ],
                    total: 21.97
                ),
            ]
        )
        let updated = makeExpense(
            id: original.id,
            merchant: "Target Updated",
            total: 23.50,
            category: "Haircare",
            items: original.items,
            groups: original.groups
        )

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        try await repository.insert(original)
        let insertedExpenses = try await repository.fetchExpenses()
        XCTAssertEqual(snapshot(insertedExpenses), snapshot([original]))

        try await repository.update(updated)
        let updatedExpenses = try await repository.fetchExpenses()
        XCTAssertEqual(snapshot(updatedExpenses), snapshot([updated]))

        try await repository.delete(id: updated.id)
        let deletedExpenses = try await repository.fetchExpenses()
        XCTAssertEqual(deletedExpenses, [])
    }

    func testSupabaseRepositoryMigratesLegacyLocalExpensesIntoRemoteAndScopedCache() async throws {
        let defaults = makeUserDefaults()
        let legacyRepository = LocalExpenseRepository(
            fileURL: makeTempFileURL(),
            userDefaults: defaults
        )
        let scopedCacheRepository = LocalExpenseRepository(
            fileURL: makeTempFileURL(),
            userDefaults: defaults,
            legacyKey: "receiptly_cache_test-user"
        )
        let remoteStore = SpyExpenseRemoteStore()
        let expense = makeExpense(id: "expense-legacy", merchant: "Legacy Store", total: 42.5)

        try await legacyRepository.insert(expense)

        let repository = SupabaseExpenseRepository(
            userID: "test-user",
            remoteStore: remoteStore,
            cacheRepository: scopedCacheRepository,
            migrationSourceRepository: legacyRepository
        )

        let fetchedExpenses = try await repository.fetchExpenses()
        let scopedCachedExpenses = try await scopedCacheRepository.fetchExpenses()
        let legacyExpensesAfterMigration = try await legacyRepository.fetchExpenses()

        XCTAssertEqual(snapshot(fetchedExpenses), snapshot([expense]))
        XCTAssertEqual(snapshot(scopedCachedExpenses), snapshot([expense]))
        XCTAssertEqual(snapshot(remoteStore.storedRows.map { $0.asExpense() }), snapshot([expense]))
        XCTAssertEqual(remoteStore.storedRows.first?.userID, "test-user")
        XCTAssertEqual(legacyExpensesAfterMigration, [])
    }

    func testSupabaseRepositoryKeepsScopedCacheWhenRemoteInsertFails() async throws {
        let defaults = makeUserDefaults()
        let scopedCacheRepository = LocalExpenseRepository(
            fileURL: makeTempFileURL(),
            userDefaults: defaults,
            legacyKey: "receiptly_cache_test-user"
        )
        let remoteStore = SpyExpenseRemoteStore()
        remoteStore.writeError = TestLocalizedError(message: "remote save failed")
        let repository = SupabaseExpenseRepository(
            userID: "test-user",
            remoteStore: remoteStore,
            cacheRepository: scopedCacheRepository,
            migrationSourceRepository: LocalExpenseRepository(
                fileURL: makeTempFileURL(),
                userDefaults: defaults,
                legacyKey: "receiptly_v8_test-user"
            ),
            clearsMigrationSourceAfterSync: false
        )
        let expense = makeExpense(id: "expense-1", merchant: "Target", total: 12.5)

        do {
            try await repository.insert(expense)
            XCTFail("Expected remote insert to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "remote save failed")
        }

        let scopedCachedExpenses = try await scopedCacheRepository.fetchExpenses()

        XCTAssertEqual(snapshot(scopedCachedExpenses), snapshot([expense]))
        XCTAssertEqual(remoteStore.upsertCallCount, 1)
    }

    func testSupabaseRepositoryDeleteAllClearsRemoteAndScopedCache() async throws {
        let defaults = makeUserDefaults()
        let expense = makeExpense(id: "expense-delete-all", merchant: "Target", total: 12.5)
        let scopedCacheRepository = LocalExpenseRepository(
            fileURL: makeTempFileURL(),
            userDefaults: defaults,
            legacyKey: "receiptly_cache_test-user"
        )
        try scopedCacheRepository.replaceAll(with: [expense])

        let remoteStore = SpyExpenseRemoteStore(
            initialRows: [ExpenseRow(expense: expense, userID: "test-user")]
        )
        let repository = SupabaseExpenseRepository(
            userID: "test-user",
            remoteStore: remoteStore,
            cacheRepository: scopedCacheRepository,
            migrationSourceRepository: LocalExpenseRepository(
                fileURL: makeTempFileURL(),
                userDefaults: defaults,
                legacyKey: "receiptly_v8_test-user"
            ),
            clearsMigrationSourceAfterSync: false
        )

        try await repository.deleteAll()

        let scopedCachedExpenses = try await scopedCacheRepository.fetchExpenses()

        XCTAssertEqual(scopedCachedExpenses, [])
        XCTAssertEqual(remoteStore.storedRows, [])
        XCTAssertEqual(remoteStore.deleteAllCallCount, 1)
    }

    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "ReceiptlyNativeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
