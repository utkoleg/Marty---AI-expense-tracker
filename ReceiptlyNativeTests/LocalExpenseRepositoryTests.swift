import XCTest
@testable import ReceiptlyNative

final class LocalExpenseRepositoryTests: XCTestCase {
    func testLoadReadsSavedJSONFile() throws {
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

        XCTAssertEqual(snapshot(repository.load()), snapshot(expenses))
    }

    func testLoadFallsBackToLegacyUserDefaults() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        let expenses = [
            makeExpense(id: "expense-legacy", merchant: "CVS", total: 8.48),
        ]
        let data = try JSONEncoder().encode(expenses)
        defaults.set(String(decoding: data, as: UTF8.self), forKey: "receiptly_v8")

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        XCTAssertEqual(snapshot(repository.load()), snapshot(expenses))
    }

    func testLoadReturnsEmptyWhenFileAndLegacyAreInvalid() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        try Data("not-json".utf8).write(to: fileURL, options: [.atomic])
        defaults.set("still-not-json", forKey: "receiptly_v8")

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        XCTAssertEqual(repository.load(), [])
    }

    func testSaveRoundTripsWithoutChangingExpenseContent() throws {
        let fileURL = makeTempFileURL()
        let defaults = makeUserDefaults()
        let expenses = [
            makeExpense(
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
            ),
        ]

        let repository = LocalExpenseRepository(fileURL: fileURL, userDefaults: defaults)

        try repository.save(expenses)

        XCTAssertEqual(snapshot(repository.load()), snapshot(expenses))
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
