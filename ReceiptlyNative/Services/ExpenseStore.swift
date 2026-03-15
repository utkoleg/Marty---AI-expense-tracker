import Foundation
import Combine

// MARK: - Stats

struct Stats {
    var totalSpent: Double = 0
    var catTotals: [String: Double] = [:]
    var catCounts: [String: Int] = [:]
    var monthlyTotals: [String: Double] = [:]
    var topCat: String? = nil
    var usedCats: [String] = []
    var thisMonth: String = currentMonthKey()
    var displayCurrency: String = currentBaseCurrencyCode()
}

// MARK: - ExpenseStore

/// Single source of truth for expenses backed by an injected repository.
@MainActor
final class ExpenseStore: ObservableObject {

    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var stats: Stats = Stats()
    private let repository: any ExpenseRepository

    init(repository: any ExpenseRepository) {
        self.repository = repository
        expenses = repository.load()
        stats = computeStats(expenses)
    }

    // MARK: - CRUD

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        persist()
    }

    func update(_ expense: Expense) {
        guard let idx = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[idx] = expense
        persist()
    }

    func delete(id: String) {
        expenses.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        expenses = []
        persist()
    }

    func reload() {
        expenses = repository.load()
        stats = computeStats(expenses)
    }

    func refreshStats() {
        stats = computeStats(expenses)
    }

    func refreshCurrencySnapshots(
        using exchangeRates: any ExchangeRateProviding,
        baseCurrency: String = currentBaseCurrencyCode(),
        expenseIDs: Set<String>? = nil
    ) async {
        guard !expenses.isEmpty else {
            stats = computeStats(expenses)
            return
        }

        let normalizedBase = normalizedCurrencyCode(baseCurrency)
        var nextExpenses = expenses
        var quotesByPair: [String: ExchangeRateQuote] = [:]
        var didChange = false

        for index in nextExpenses.indices {
            let expense = nextExpenses[index]
            guard expenseIDs?.contains(expense.id) != false else { continue }

            let normalizedOriginalCurrency = normalizedCurrencyCode(expense.currency)
            var updatedExpense = expense
            updatedExpense.currency = normalizedOriginalCurrency

            if normalizedOriginalCurrency == normalizedBase {
                didChange = didChange || applyConversionSnapshot(
                    to: &updatedExpense,
                    convertedTotal: updatedExpense.total,
                    convertedCurrency: normalizedBase,
                    exchangeRate: 1,
                    effectiveAt: ISO8601DateFormatter().string(from: Date())
                )
                nextExpenses[index] = updatedExpense
                continue
            }

            let pairKey = "\(normalizedOriginalCurrency)->\(normalizedBase)"

            do {
                let quote: ExchangeRateQuote
                if let cached = quotesByPair[pairKey] {
                    quote = cached
                } else {
                    let fetched = try await exchangeRates.latestRate(from: normalizedOriginalCurrency, to: normalizedBase)
                    quotesByPair[pairKey] = fetched
                    quote = fetched
                }

                let convertedTotal = sanitizePriceValue(updatedExpense.total * quote.rate)
                didChange = didChange || applyConversionSnapshot(
                    to: &updatedExpense,
                    convertedTotal: convertedTotal,
                    convertedCurrency: normalizedBase,
                    exchangeRate: quote.rate,
                    effectiveAt: quote.effectiveAt ?? quote.fetchedAt
                )
                nextExpenses[index] = updatedExpense
            } catch {
                AppLogger.currency.error(
                    "Exchange rate refresh failed for \(normalizedOriginalCurrency, privacy: .public)->\(normalizedBase, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                nextExpenses[index] = updatedExpense
            }
        }

        expenses = nextExpenses
        stats = computeStats(nextExpenses)

        guard didChange else { return }

        do {
            try repository.save(nextExpenses)
        } catch {
            AppLogger.persistence.error("Expense persistence failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Persistence

    private func persist() {
        stats = computeStats(expenses)
        do {
            try repository.save(expenses)
        } catch {
            AppLogger.persistence.error("Expense persistence failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Stats computation  (mirrors useExpenses.js useMemo exactly)

    private func computeStats(_ expenses: [Expense]) -> Stats {
        let baseCurrency = currentBaseCurrencyCode()
        var totalSpent: Double = 0
        var catTotals: [String: Double] = [:]
        var catCounts: [String: Int] = [:]
        var monthlyTotals: [String: Double] = [:]

        for e in expenses {
            let expenseTotal = e.displayTotal(for: baseCurrency)
            totalSpent += expenseTotal

            if let groups = e.groups, !groups.isEmpty {
                // Multi-category: attribute totals per group category
                for g in groups {
                    catTotals[g.category, default: 0] += e.convertedAmount(for: g.total, baseCurrency: baseCurrency) ?? g.total
                }
                // Count expense once per category it appears in
                let seen = Set(groups.map(\.category))
                for cat in seen {
                    catCounts[cat, default: 0] += 1
                }
            } else {
                catTotals[e.category, default: 0] += expenseTotal
                catCounts[e.category, default: 0] += 1
            }

            let month = String(e.date.prefix(7))
            if !month.isEmpty {
                monthlyTotals[month, default: 0] += expenseTotal
            }
        }

        let topCat = catTotals.max(by: { $0.value < $1.value })?.key
        let usedCats = catTotals.keys.sorted { catTotals[$0]! > catTotals[$1]! }

        return Stats(
            totalSpent: totalSpent,
            catTotals: catTotals,
            catCounts: catCounts,
            monthlyTotals: monthlyTotals,
            topCat: topCat,
            usedCats: usedCats,
            thisMonth: currentMonthKey(),
            displayCurrency: baseCurrency
        )
    }

    private func applyConversionSnapshot(
        to expense: inout Expense,
        convertedTotal: Double,
        convertedCurrency: String,
        exchangeRate: Double,
        effectiveAt: String
    ) -> Bool {
        let normalizedConvertedCurrency = normalizedCurrencyCode(convertedCurrency)
        let normalizedOriginalCurrency = normalizedCurrencyCode(expense.currency)

        let hasChanged = expense.currency != normalizedOriginalCurrency
            || expense.convertedTotal != convertedTotal
            || expense.convertedCurrency != normalizedConvertedCurrency
            || expense.exchangeRate != exchangeRate
            || expense.exchangeRateUpdatedAt != effectiveAt

        expense.currency = normalizedOriginalCurrency
        expense.convertedTotal = convertedTotal
        expense.convertedCurrency = normalizedConvertedCurrency
        expense.exchangeRate = exchangeRate
        expense.exchangeRateUpdatedAt = effectiveAt
        return hasChanged
    }
}

// MARK: - CSV Export

extension ExpenseStore {
    func csvString() -> String {
        ExpenseCSVExporter.csvString(from: expenses)
    }
}
