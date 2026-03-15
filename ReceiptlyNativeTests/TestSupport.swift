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
    var saveCallCount = 0
    var saveError: Error?

    init(initialExpenses: [Expense] = []) {
        storedExpenses = initialExpenses
    }

    func load() -> [Expense] {
        storedExpenses
    }

    func save(_ expenses: [Expense]) throws {
        saveCallCount += 1
        if let saveError {
            throw saveError
        }

        storedExpenses = expenses
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

struct TestLocalizedError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
