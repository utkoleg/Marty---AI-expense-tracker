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
}

// MARK: - ExpenseStore

/// Single source of truth for expenses. Persists to a JSON file in the app's
/// Documents directory (compatible with the JS app's localStorage schema).
@MainActor
final class ExpenseStore: ObservableObject {

    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var stats: Stats = Stats()
    private let persistEnabled: Bool

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("receiptly_v8.json")
    }()

    init() {
        persistEnabled = true
        expenses = load()
        stats = computeStats(expenses)
    }

    /// In-memory seed for SwiftUI previews. Does not read/write disk.
    init(previewExpenses: [Expense]) {
        persistEnabled = false
        expenses = previewExpenses
        stats = computeStats(previewExpenses)
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
        guard persistEnabled else {
            stats = computeStats(expenses)
            return
        }
        expenses = load()
        stats = computeStats(expenses)
    }

    // MARK: - Persistence

    private func persist() {
        stats = computeStats(expenses)
        guard persistEnabled else { return }
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Log; app still works in-memory
            print("[ExpenseStore] persist failed:", error)
        }
    }

    private func load() -> [Expense] {
        // Try new file location first
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            return decoded
        }
        // Fallback: try legacy UserDefaults key (in case the JS app's WebView
        // stored data there before the native rewrite)
        if let raw = UserDefaults.standard.string(forKey: "receiptly_v8"),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            return decoded
        }
        return []
    }

    // MARK: - Stats computation  (mirrors useExpenses.js useMemo exactly)

    private func computeStats(_ expenses: [Expense]) -> Stats {
        var totalSpent: Double = 0
        var catTotals: [String: Double] = [:]
        var catCounts: [String: Int] = [:]
        var monthlyTotals: [String: Double] = [:]

        for e in expenses {
            totalSpent += e.total

            if let groups = e.groups, !groups.isEmpty {
                // Multi-category: attribute totals per group category
                for g in groups {
                    catTotals[g.category, default: 0] += g.total
                }
                // Count expense once per category it appears in
                let seen = Set(groups.map(\.category))
                for cat in seen {
                    catCounts[cat, default: 0] += 1
                }
            } else {
                catTotals[e.category, default: 0] += e.total
                catCounts[e.category, default: 0] += 1
            }

            let month = String(e.date.prefix(7))
            if !month.isEmpty {
                monthlyTotals[month, default: 0] += e.total
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
            thisMonth: currentMonthKey()
        )
    }
}

// MARK: - CSV Export

extension ExpenseStore {
    func csvString() -> String {
        var rows: [[String]] = [["Date", "Merchant", "Category", "Total", "Items"]]
        for e in expenses {
            let itemNames = e.items.map(\.name).joined(separator: "; ")
            rows.append([e.date, e.merchant, e.category, String(format: "%.2f", e.total), itemNames])
        }
        return rows
            .map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }
            .joined(separator: "\n")
    }
}
