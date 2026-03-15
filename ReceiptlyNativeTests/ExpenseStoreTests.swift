import XCTest
@testable import ReceiptlyNative

@MainActor
final class ExpenseStoreTests: XCTestCase {
    private var originalBaseCurrency: String?

    override func setUp() {
        super.setUp()
        originalBaseCurrency = UserDefaults.standard.string(forKey: AppPreferences.baseCurrencyKey)
        UserDefaults.standard.set("USD", forKey: AppPreferences.baseCurrencyKey)
    }

    override func tearDown() {
        if let originalBaseCurrency {
            UserDefaults.standard.set(originalBaseCurrency, forKey: AppPreferences.baseCurrencyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AppPreferences.baseCurrencyKey)
        }

        super.tearDown()
    }

    func testCRUDOperationsUpdateExpensesAndStats() async {
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

        store.delete(id: "expense-1")

        XCTAssertEqual(store.expenses.map(\.id), ["expense-2"])
        XCTAssertEqual(store.stats.totalSpent, 25)

        store.clearAll()

        XCTAssertEqual(store.expenses, [])
        XCTAssertEqual(store.stats.totalSpent, 0)

        await XCTAssertEventually {
            repository.insertCallCount == 2 &&
                repository.updateCallCount == 1 &&
                repository.deleteCallCount == 1 &&
                repository.deleteAllCallCount == 1
        }
    }

    func testReloadRefreshesFromRepository() async {
        let original = makeExpense(id: "expense-1", merchant: "Old")
        let replacement = makeExpense(id: "expense-2", merchant: "New")
        let repository = SpyExpenseRepository(initialExpenses: [original])
        let store = ExpenseStore(repository: repository)

        repository.storedExpenses = [replacement]
        await store.reload()

        XCTAssertEqual(snapshot(store.expenses), snapshot([replacement]))
        XCTAssertEqual(store.stats.totalSpent, replacement.total)
        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    func testWriteErrorDoesNotRollbackInMemoryChanges() async {
        let repository = SpyExpenseRepository()
        repository.writeError = TestLocalizedError(message: "save failed")
        let store = ExpenseStore(repository: repository)
        let expense = makeExpense(id: "expense-1", merchant: "Target", total: 12.5)

        store.add(expense)

        XCTAssertEqual(snapshot(store.expenses), snapshot([expense]))
        XCTAssertEqual(store.stats.totalSpent, 12.5)
        XCTAssertEqual(repository.storedExpenses, [])

        await XCTAssertEventually {
            repository.insertCallCount == 1
        }
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
        XCTAssertEqual(repository.updateCallCount, 1)
    }

    func testRefreshCurrencySnapshotsReplacesConversionWhenBaseCurrencyChanges() async {
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
        let rates = PairExchangeRateService(rates: [
            "KZT->USD": 0.002,
            "KZT->EUR": 0.0018,
        ])

        await store.refreshCurrencySnapshots(using: rates, baseCurrency: "USD")

        XCTAssertEqual(store.expenses.first?.convertedTotal, 100)
        XCTAssertEqual(store.expenses.first?.convertedCurrency, "USD")
        XCTAssertEqual(store.stats.totalSpent, 100)
        XCTAssertEqual(store.stats.displayCurrency, "USD")

        await store.refreshCurrencySnapshots(using: rates, baseCurrency: "EUR")

        XCTAssertEqual(store.expenses.first?.convertedTotal, 90)
        XCTAssertEqual(store.expenses.first?.convertedCurrency, "EUR")
        XCTAssertEqual(store.expenses.first?.exchangeRate, 0.0018)
        XCTAssertEqual(store.stats.totalSpent, 90)
        XCTAssertEqual(store.stats.displayCurrency, "EUR")
        XCTAssertEqual(repository.updateCallCount, 2)
    }

    func testRefreshCurrencySnapshotsDoesNotTreatOriginalAmountAsBaseOnFailedRefresh() async {
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

        await store.refreshCurrencySnapshots(using: StubExchangeRateService(outcome: .success(0.002)), baseCurrency: "USD")
        await store.refreshCurrencySnapshots(
            using: StubExchangeRateService(outcome: .failure(TestLocalizedError(message: "rate unavailable"))),
            baseCurrency: "EUR"
        )

        XCTAssertEqual(store.expenses.first?.convertedTotal, 100)
        XCTAssertEqual(store.expenses.first?.convertedCurrency, "USD")
        XCTAssertEqual(store.stats.totalSpent, 0)
        XCTAssertEqual(store.stats.displayCurrency, "EUR")
        XCTAssertEqual(repository.updateCallCount, 1)
    }
}
