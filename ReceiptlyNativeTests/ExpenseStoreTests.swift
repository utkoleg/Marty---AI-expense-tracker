import XCTest
@testable import ReceiptlyNative

@MainActor
final class ExpenseStoreTests: XCTestCase {
    func testCRUDOperationsUpdateExpensesAndStats() {
        let repository = SpyExpenseRepository()
        let store = ExpenseStore(repository: repository)
        let groceries = makeExpense(
            id: "expense-1",
            merchant: "Trader Joe's",
            date: "2024-12-01",
            total: 10,
            category: "Groceries",
            items: [makeExpenseItem(name: "Fruit", quantity: 1, price: 10)]
        )
        let dining = makeExpense(
            id: "expense-2",
            merchant: "Cafe",
            date: "2024-12-15",
            total: 20,
            category: "Dining",
            items: [makeExpenseItem(name: "Lunch", quantity: 1, price: 20)]
        )

        store.add(groceries)
        store.add(dining)

        XCTAssertEqual(store.expenses.map(\.id), ["expense-2", "expense-1"])
        XCTAssertEqual(store.stats.totalSpent, 30)
        XCTAssertEqual(store.stats.catTotals["Groceries"], 10)
        XCTAssertEqual(store.stats.catTotals["Dining"], 20)
        XCTAssertEqual(store.stats.monthlyTotals["2024-12"], 30)
        XCTAssertEqual(store.stats.topCat, "Dining")

        let updatedDining = makeExpense(
            id: "expense-2",
            merchant: "Cafe",
            date: "2024-12-15",
            total: 25,
            category: "Dining",
            items: [makeExpenseItem(name: "Lunch", quantity: 1, price: 25)],
            addedAt: dining.addedAt
        )
        store.update(updatedDining)

        XCTAssertEqual(store.expenses.first?.total, 25)
        XCTAssertEqual(store.stats.totalSpent, 35)
        XCTAssertEqual(repository.saveCallCount, 3)

        store.delete(id: "expense-1")

        XCTAssertEqual(store.expenses.map(\.id), ["expense-2"])
        XCTAssertEqual(store.stats.totalSpent, 25)

        store.clearAll()

        XCTAssertEqual(store.expenses, [])
        XCTAssertEqual(store.stats.totalSpent, 0)
        XCTAssertEqual(repository.saveCallCount, 5)
    }

    func testReloadRefreshesFromRepository() {
        let original = makeExpense(id: "expense-1", merchant: "Old")
        let replacement = makeExpense(id: "expense-2", merchant: "New")
        let repository = SpyExpenseRepository(initialExpenses: [original])
        let store = ExpenseStore(repository: repository)

        repository.storedExpenses = [replacement]
        store.reload()

        XCTAssertEqual(snapshot(store.expenses), snapshot([replacement]))
        XCTAssertEqual(store.stats.totalSpent, replacement.total)
    }

    func testSaveErrorDoesNotRollbackInMemoryChanges() {
        let repository = SpyExpenseRepository()
        repository.saveError = TestLocalizedError(message: "save failed")
        let store = ExpenseStore(repository: repository)
        let expense = makeExpense(id: "expense-1", merchant: "Target", total: 12.5)

        store.add(expense)

        XCTAssertEqual(snapshot(store.expenses), snapshot([expense]))
        XCTAssertEqual(store.stats.totalSpent, 12.5)
        XCTAssertEqual(repository.storedExpenses, [])
        XCTAssertEqual(repository.saveCallCount, 1)
    }

    func testRefreshCurrencySnapshotsUpdatesConvertedTotalsAndStats() async {
        let repository = SpyExpenseRepository(initialExpenses: [
            makeExpense(
                id: "expense-kzt",
                merchant: "Magnum",
                total: 50_000,
                currency: "KZT",
                category: "Groceries"
            ),
        ])
        let store = ExpenseStore(repository: repository)
        let rates = StubExchangeRateService(outcome: .success(0.002))

        await store.refreshCurrencySnapshots(using: rates, baseCurrency: "USD")

        XCTAssertEqual(store.expenses.first?.convertedTotal, 100)
        XCTAssertEqual(store.expenses.first?.convertedCurrency, "USD")
        XCTAssertEqual(store.expenses.first?.exchangeRate, 0.002)
        XCTAssertEqual(store.stats.totalSpent, 100)
        XCTAssertEqual(repository.saveCallCount, 1)
    }
}
