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
    private var hasLoadedRemoteState = false
    private var persistenceTask: Task<Void, Never>?

    init(repository: any ExpenseRepository) {
        self.repository = repository
        expenses = repository.cachedExpenses
        stats = computeStats(expenses)
    }

    // MARK: - CRUD

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        persist(expenses)
        enqueuePersistence {
            do {
                try await self.repository.insert(expense)
            } catch {
                AppLogger.persistence.error("Expense insert failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func update(_ expense: Expense) {
        guard let idx = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[idx] = expense
        persist(expenses)
        enqueuePersistence {
            do {
                try await self.repository.update(expense)
            } catch {
                AppLogger.persistence.error("Expense update failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func delete(id: String) {
        expenses.removeAll { $0.id == id }
        persist(expenses)
        enqueuePersistence {
            do {
                try await self.repository.delete(id: id)
            } catch {
                AppLogger.persistence.error("Expense delete failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func clearAll() {
        expenses = []
        persist(expenses)
        enqueuePersistence {
            do {
                try await self.repository.deleteAll()
            } catch {
                AppLogger.persistence.error("Expense clear failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func loadIfNeeded() async {
        guard !hasLoadedRemoteState else { return }
        await reload()
    }

    func reload() async {
        await persistenceTask?.value

        do {
            let fetchedExpenses = try await repository.fetchExpenses()
            expenses = fetchedExpenses
            stats = computeStats(fetchedExpenses)
            hasLoadedRemoteState = true
        } catch {
            AppLogger.persistence.error("Expense fetch failed: \(String(describing: error), privacy: .public)")
        }
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
        var changedExpenseIDs: Set<String> = []

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
                if updatedExpense != expense {
                    changedExpenseIDs.insert(updatedExpense.id)
                }
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
                if updatedExpense != expense {
                    changedExpenseIDs.insert(updatedExpense.id)
                }
                nextExpenses[index] = updatedExpense
            } catch {
                AppLogger.currency.error(
                    "Exchange rate refresh failed for \(normalizedOriginalCurrency, privacy: .public)->\(normalizedBase, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                nextExpenses[index] = updatedExpense
            }
        }

        expenses = nextExpenses
        stats = computeStats(nextExpenses, baseCurrency: normalizedBase)

        guard didChange else { return }

        let changedExpenses = nextExpenses.filter { changedExpenseIDs.contains($0.id) }

        enqueuePersistence {
            for expense in changedExpenses {
                do {
                    try await self.repository.update(expense)
                } catch {
                    AppLogger.persistence.error("Expense currency snapshot update failed: \(String(describing: error), privacy: .public)")
                }
            }
        }

        await persistenceTask?.value
    }

    // MARK: - Persistence

    private func persist(_ expenses: [Expense]) {
        stats = computeStats(expenses)
    }

    private func enqueuePersistence(_ operation: @escaping @MainActor () async -> Void) {
        let previousTask = persistenceTask

        persistenceTask = Task { @MainActor in
            await previousTask?.value
            await operation()
        }
    }

    // MARK: - Stats computation  (mirrors useExpenses.js useMemo exactly)

    private func computeStats(_ expenses: [Expense], baseCurrency: String = currentBaseCurrencyCode()) -> Stats {
        let normalizedBaseCurrency = normalizedCurrencyCode(baseCurrency)
        var totalSpent: Double = 0
        var catTotals: [String: Double] = [:]
        var catCounts: [String: Int] = [:]
        var monthlyTotals: [String: Double] = [:]

        for e in expenses {
            let expenseTotal = e.displayedBaseAmount(for: e.total, baseCurrency: normalizedBaseCurrency) ?? 0
            totalSpent += expenseTotal

            if let groups = e.groups, !groups.isEmpty {
                // Multi-category: attribute totals per group category
                for g in groups {
                    let groupTotal = e.displayedBaseAmount(for: g.total, baseCurrency: normalizedBaseCurrency) ?? 0
                    catTotals[g.category, default: 0] += groupTotal
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
            displayCurrency: normalizedBaseCurrency
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
