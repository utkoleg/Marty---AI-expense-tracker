import SwiftUI

struct HomeView: View {
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @State private var recentExpensesLimit = 7

    let expenses: [Expense]
    let stats: Stats
    let isLoading: Bool
    let flash: Expense?
    let isFlashVisible: Bool
    var onScanPress: () -> Void
    var onManualPress: () -> Void
    var onFlashPress: (Expense) -> Void
    var onExpensePress: (Expense) -> Void
    var onDeletePress: (String) -> Void
    var onRefresh: () async -> Void

    private var sorted: [Expense] {
        expenses.sorted { $0.date > $1.date }
    }

    private var topCategorySummary: (name: String, total: Double, color: Color)? {
        guard let top = stats.topCat else { return nil }
        return (top, stats.catTotals[top] ?? 0, categoryInfo(for: top).color)
    }

    private var visibleRecentExpenses: [Expense] {
        Array(sorted.prefix(recentExpensesLimit))
    }

    private var canLoadMoreRecentExpenses: Bool {
        visibleRecentExpenses.count < sorted.count
    }

    var body: some View {
        List {
            Section {
                QuickCaptureCard(
                    expenseCount: expenses.count,
                    monthLabel: formatMonth(stats.thisMonth),
                    monthTotal: stats.monthlyTotals[stats.thisMonth] ?? 0,
                    baseCurrency: stats.displayCurrency,
                    isLoading: isLoading,
                    onScanPress: onScanPress,
                    onManualPress: onManualPress
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            if let flash {
                Section {
                    FlashResultView(
                        expense: flash,
                        isVisible: isFlashVisible,
                        onPress: { onFlashPress(flash) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            if !expenses.isEmpty {
                Section(loc("Overview", "Сводка")) {
                    HomeStatsGrid(
                        stats: stats,
                        receiptCount: expenses.count,
                        topCategorySummary: topCategorySummary,
                        baseCurrency: stats.displayCurrency
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    MonthlyChartView(expenses: expenses, baseCurrency: stats.displayCurrency)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            Section(sorted.isEmpty ? "" : loc("Recent Expenses", "Последние чеки")) {
                if sorted.isEmpty {
                    EmptyStateView(
                        systemName: "doc.text.viewfinder",
                        title: loc("No receipts yet", "Чеков пока нет"),
                        message: loc(
                            "Scan a receipt or add one manually to start tracking your spending.",
                            "Сканируй чек или добавь его вручную, чтобы начать учет расходов."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleRecentExpenses) { expense in
                        ExpenseRowView(
                            expense: expense,
                            onPress: onExpensePress
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDeletePress(expense.id)
                            } label: {
                                Label(loc("Delete", "Удалить"), systemImage: "trash")
                            }
                            .tint(AppColor.danger)
                        }
                    }

                    if canLoadMoreRecentExpenses {
                        Button {
                            Haptics.light()
                            recentExpensesLimit += 7
                        } label: {
                            Text(loc("Load More", "Еще"))
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColor.accent)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.bg)
        .id(appLanguageRawValue)
        .refreshable { await onRefresh() }
    }
}

private struct QuickCaptureCard: View {
    let expenseCount: Int
    let monthLabel: String
    let monthTotal: Double
    let baseCurrency: String
    let isLoading: Bool
    var onScanPress: () -> Void
    var onManualPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("Capture a receipt", "Новый чек"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.text)

                Text(loc(
                    "Scan with the camera or bring in a photo from your library. Marty keeps everything organized automatically.",
                    "Сфотографируй чек или выбери фото из галереи. Marty сам разложит все по категориям."
                ))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
            }

            HStack(spacing: 12) {
                SummaryChip(
                    title: monthLabel,
                    value: fmt(monthTotal, currencyCode: baseCurrency),
                    systemName: "calendar"
                )

                SummaryChip(
                    title: loc("Receipts", "Чеки"),
                    value: "\(expenseCount)",
                    systemName: "doc.text"
                )
            }

            if isLoading {
                VStack(alignment: .leading, spacing: 10) {
                    Label(loc("Analyzing receipt", "Разбираем чек"), systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(AppColor.text)

                    ProgressView()
                        .tint(AppColor.accent)

                    Text(loc(
                        "Reading merchant, date, items, and categories.",
                        "Считываем магазин, дату и позиции."
                    ))
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Button(action: {
                        Haptics.heavy()
                        onScanPress()
                    }) {
                        QuickCaptureActionLabel(
                            title: loc("Scan Receipt", "Сканировать"),
                            systemName: "doc.viewfinder"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.accent)

                    Button(action: {
                        Haptics.light()
                        onManualPress()
                    }) {
                        QuickCaptureActionLabel(
                            title: loc("Add Manually", "Вручную"),
                            systemName: "square.and.pencil"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(AppColor.accent)
                }
            }
        }
        .padding(20)
        .cardStyle(fill: AppColor.surface, stroke: AppColor.hairline)
    }
}

private struct QuickCaptureActionLabel: View {
    let title: String
    let systemName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(width: 18, alignment: .center)

            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeStatsGrid: View {
    let stats: Stats
    let receiptCount: Int
    let topCategorySummary: (name: String, total: Double, color: Color)?
    let baseCurrency: String

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 12) {
                StatCardView(
                    label: loc("Total Spent", "Потрачено"),
                    value: fmt(stats.totalSpent, currencyCode: baseCurrency),
                    color: AppColor.accent,
                    symbolName: "dollarsign.circle"
                )

                StatCardView(
                    label: loc("Receipts", "Чеки"),
                    value: "\(receiptCount)",
                    color: AppColor.success,
                    symbolName: "doc.text"
                )

                StatCardView(
                    label: loc("This Month", "За месяц"),
                    value: fmt(stats.monthlyTotals[stats.thisMonth] ?? 0, currencyCode: baseCurrency),
                    color: AppColor.warning,
                    symbolName: "calendar"
                )

                if let topCategorySummary {
                    StatCardView(
                        label: loc("Top Category", "Лидер"),
                        value: localizedCategoryName(topCategorySummary.name),
                        sub: fmt(topCategorySummary.total, currencyCode: baseCurrency),
                        color: topCategorySummary.color,
                        symbolName: "chart.pie"
                    )
                } else {
                    StatCardView(
                        label: loc("Top Category", "Лидер"),
                        value: loc("None yet", "Пока нет"),
                        color: AppColor.muted,
                        symbolName: "chart.pie"
                    )
                }
            }
        }
        .padding(20)
        .cardStyle(fill: AppColor.surface, stroke: AppColor.hairline)
    }
}

#Preview("Home - With Data") {
    NavigationStack {
        HomeView(
            expenses: previewExpenses,
            stats: previewStats,
            isLoading: false,
            flash: previewExpenses.first,
            isFlashVisible: true,
            onScanPress: {},
            onManualPress: {},
            onFlashPress: { _ in },
            onExpensePress: { _ in },
            onDeletePress: { _ in },
            onRefresh: {}
        )
        .navigationTitle("Marty")
    }
    .preferredColorScheme(.light)
}

#Preview("Home - Loading") {
    NavigationStack {
        HomeView(
            expenses: [],
            stats: Stats(),
            isLoading: true,
            flash: nil,
            isFlashVisible: false,
            onScanPress: {},
            onManualPress: {},
            onFlashPress: { _ in },
            onExpensePress: { _ in },
            onDeletePress: { _ in },
            onRefresh: {}
        )
        .navigationTitle("Marty")
    }
    .preferredColorScheme(.light)
}

private let previewExpenses: [Expense] = [
    Expense(
        merchant: "GNC",
        date: "2024-12-11",
        total: 151.33,
        category: "Pharmacy",
        items: [
            ExpenseItem(name: "Creatine", quantity: 1, price: 49.99),
            ExpenseItem(name: "Vitamins", quantity: 1, price: 24.99),
            ExpenseItem(name: "Protein", quantity: 1, price: 76.35),
        ]
    ),
    Expense(
        merchant: "Sweetgreen",
        date: "2024-12-08",
        total: 18.42,
        category: "Dining",
        items: [
            ExpenseItem(name: "Harvest Bowl", quantity: 1, price: 18.42),
        ]
    ),
]

private let previewStats = Stats(
    totalSpent: 169.75,
    catTotals: [
        "Pharmacy": 151.33,
        "Dining": 18.42,
    ],
    catCounts: [
        "Pharmacy": 1,
        "Dining": 1,
    ],
    monthlyTotals: [
        "2024-10": 121.89,
        "2024-11": 142.10,
        "2024-12": 169.75,
    ],
    topCat: "Pharmacy",
    usedCats: ["Pharmacy", "Dining"],
    thisMonth: "2024-12"
)
