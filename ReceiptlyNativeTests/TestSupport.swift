import XCTest
import UIKit
@testable import ReceiptlyNative

struct ExpenseSnapshot: Equatable {
    let id: String
    let merchant: String
    let date: String
    let total: Double
    let currency: String
    let category: String
    let notes: String
    let addedAt: String
    let items: [ExpenseItemSnapshot]
    let groups: [ExpenseGroupSnapshot]?
}

struct ExpenseItemSnapshot: Equatable {
    let name: String
    let quantity: Int
    let price: Double
}

struct ExpenseGroupSnapshot: Equatable {
    let category: String
    let total: Double
    let items: [ExpenseItemSnapshot]
}

func snapshot(_ expenses: [Expense]) -> [ExpenseSnapshot] {
    expenses.map(snapshot)
}

func snapshot(_ expense: Expense) -> ExpenseSnapshot {
    ExpenseSnapshot(
        id: expense.id,
        merchant: expense.merchant,
        date: expense.date,
        total: expense.total,
        currency: expense.currency,
        category: expense.category,
        notes: expense.notes,
        addedAt: expense.addedAt,
        items: expense.items.map(snapshot),
        groups: expense.groups?.map(snapshot)
    )
}

func snapshot(_ item: ExpenseItem) -> ExpenseItemSnapshot {
    ExpenseItemSnapshot(name: item.name, quantity: item.quantity, price: item.price)
}

func snapshot(_ group: ExpenseGroup) -> ExpenseGroupSnapshot {
    ExpenseGroupSnapshot(
        category: group.category,
        total: group.total,
        items: group.items.map(snapshot)
    )
}

func makeExpense(
    id: String = UUID().uuidString,
    merchant: String = "Target",
    date: String = "2024-12-11",
    total: Double = 21.97,
    currency: String = "USD",
    category: String = "Groceries",
    items: [ExpenseItem] = [ExpenseItem(name: "Milk", quantity: 1, price: 21.97)],
    notes: String = "",
    addedAt: String = "2024-12-11T12:00:00Z",
    groups: [ExpenseGroup]? = nil,
    convertedTotal: Double? = nil,
    convertedCurrency: String? = nil,
    exchangeRate: Double? = nil,
    exchangeRateUpdatedAt: String? = nil
) -> Expense {
    Expense(
        id: id,
        merchant: merchant,
        date: date,
        total: total,
        currency: currency,
        convertedTotal: convertedTotal,
        convertedCurrency: convertedCurrency,
        exchangeRate: exchangeRate,
        exchangeRateUpdatedAt: exchangeRateUpdatedAt,
        category: category,
        items: items,
        notes: notes,
        addedAt: addedAt,
        groups: groups
    )
}

func makeExpenseItem(name: String = "Milk", quantity: Int = 1, price: Double = 3.50) -> ExpenseItem {
    ExpenseItem(name: name, quantity: quantity, price: price)
}

func makeExpenseGroup(
    category: String = "Groceries",
    items: [ExpenseItem] = [makeExpenseItem()],
    total: Double = 3.50
) -> ExpenseGroup {
    ExpenseGroup(category: category, items: items, total: total)
}

func makeReceiptGroup(
    merchant: String? = "Target",
    date: String? = "2024-12-11",
    currency: String? = "USD",
    notes: String? = "",
    category: String = "Groceries",
    items: [ReceiptGroup.RawItem] = [ReceiptGroup.RawItem(name: "Milk", quantity: 1, price: FlexDouble(3.50))],
    total: Double? = 3.50
) -> ReceiptGroup {
    ReceiptGroup(
        merchant: merchant,
        date: date,
        currency: currency,
        notes: notes,
        category: category,
        items: items,
        total: total
    )
}

func makeStagedImage() -> StagedImage {
    StagedImage(uiImage: UIImage())
}

@MainActor
func XCTAssertEventually(
    _ condition: @escaping @MainActor () -> Bool,
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }

        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    XCTFail("Condition not met within \(timeout)s", file: file, line: line)
}

final class SpyExpenseRepository: ExpenseRepository {
    var storedExpenses: [Expense]
    var fetchCallCount = 0
    var insertCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0
    var fetchError: Error?
    var writeError: Error?

    init(initialExpenses: [Expense] = []) {
        storedExpenses = initialExpenses
    }

    var cachedExpenses: [Expense] {
        storedExpenses
    }

    func fetchExpenses() async throws -> [Expense] {
        fetchCallCount += 1
        if let fetchError {
            throw fetchError
        }

        return storedExpenses
    }

    func insert(_ expense: Expense) async throws {
        insertCallCount += 1
        if let writeError {
            throw writeError
        }

        storedExpenses.removeAll { $0.id == expense.id }
        storedExpenses.insert(expense, at: 0)
    }

    func update(_ expense: Expense) async throws {
        updateCallCount += 1
        if let writeError {
            throw writeError
        }

        guard let index = storedExpenses.firstIndex(where: { $0.id == expense.id }) else { return }
        storedExpenses[index] = expense
    }

    func delete(id: String) async throws {
        deleteCallCount += 1
        if let writeError {
            throw writeError
        }

        storedExpenses.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        deleteAllCallCount += 1
        if let writeError {
            throw writeError
        }

        storedExpenses = []
    }
}

actor StubReceiptAnalyzer: ReceiptAnalyzing {
    enum Outcome {
        case success([ReceiptGroup])
        case failure(Error)
    }

    private let outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func analyze(images: [StagedImage], timeoutSeconds: Double) async throws -> [ReceiptGroup] {
        switch outcome {
        case .success(let groups):
            return groups
        case .failure(let error):
            throw error
        }
    }
}

actor StubExchangeRateService: ExchangeRateProviding {
    enum Outcome {
        case success(Double)
        case failure(Error)
    }

    private let outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func latestRate(from: String, to: String) async throws -> ExchangeRateQuote {
        switch outcome {
        case .success(let rate):
            return ExchangeRateQuote(
                from: normalizedCurrencyCode(from),
                to: normalizedCurrencyCode(to),
                rate: rate,
                fetchedAt: "2026-03-14T00:00:00Z",
                effectiveAt: "2026-03-14T00:00:00Z"
            )
        case .failure(let error):
            throw error
        }
    }
}

actor PairExchangeRateService: ExchangeRateProviding {
    private let rates: [String: Double]

    init(rates: [String: Double]) {
        self.rates = rates
    }

    func latestRate(from: String, to: String) async throws -> ExchangeRateQuote {
        let normalizedFrom = normalizedCurrencyCode(from)
        let normalizedTo = normalizedCurrencyCode(to)
        let key = "\(normalizedFrom)->\(normalizedTo)"

        guard let rate = rates[key] else {
            throw ExchangeRateError.unsupportedCurrencyPair(normalizedFrom, normalizedTo)
        }

        return ExchangeRateQuote(
            from: normalizedFrom,
            to: normalizedTo,
            rate: rate,
            fetchedAt: "2026-03-14T00:00:00Z",
            effectiveAt: "2026-03-14T00:00:00Z"
        )
    }
}

final class SpyExpenseRemoteStore: ExpenseRemoteStore {
    var storedRows: [ExpenseRow]
    var fetchCallCount = 0
    var upsertCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0
    var fetchError: Error?
    var writeError: Error?

    init(initialRows: [ExpenseRow] = []) {
        storedRows = initialRows
    }

    func fetchRows(for userID: String) async throws -> [ExpenseRow] {
        fetchCallCount += 1
        if let fetchError {
            throw fetchError
        }

        return storedRows.filter { ($0.userID ?? userID) == userID }
    }

    func upsert(_ rows: [ExpenseRow]) async throws {
        upsertCallCount += 1
        if let writeError {
            throw writeError
        }

        for row in rows.reversed() {
            storedRows.removeAll { $0.id == row.id }
            storedRows.insert(row, at: 0)
        }
    }

    func deleteExpense(id: String, userID: String) async throws {
        deleteCallCount += 1
        if let writeError {
            throw writeError
        }

        storedRows.removeAll { $0.id == id && ($0.userID ?? userID) == userID }
    }

    func deleteAllExpenses(for userID: String) async throws {
        deleteAllCallCount += 1
        if let writeError {
            throw writeError
        }

        storedRows.removeAll { ($0.userID ?? userID) == userID }
    }
}

struct TestLocalizedError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
