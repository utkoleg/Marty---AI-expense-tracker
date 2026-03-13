import SwiftUI

struct HomeView: View {
    let expenses: [Expense]
    let stats: Stats
    let isLoading: Bool
    let flash: Expense?
    var onScanPress: () -> Void
    var onExpensePress: (Expense) -> Void
    var onDeletePress: (String) -> Void
    var onRefresh: () async -> Void

    private var sorted: [Expense] {
        expenses.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Scan button / loading banner
                Group {
                    if isLoading {
                        LoadingBannerView()
                    } else {
                        ScanButtonView(onPress: onScanPress)
                    }
                }
                .padding(.bottom, 16)

                // Flash result
                AnimatingFlash(expense: flash)

                // Stats row 1
                HStack(spacing: 10) {
                    StatCardView(label: "Total Spent", value: fmt(stats.totalSpent))
                    StatCardView(label: "Receipts", value: "\(expenses.count)", color: AppColor.success)
                }
                .padding(.bottom, 10)

                // Stats row 2
                HStack(spacing: 10) {
                    StatCardView(
                        label: "This Month",
                        value: fmt(stats.monthlyTotals[stats.thisMonth] ?? 0),
                        color: AppColor.warning
                    )
                    if let top = stats.topCat {
                        let ci = categoryInfo(for: top)
                        StatCardView(
                            label: "Top Category",
                            value: "\(ci.emoji) \(top)",
                            sub: fmt(stats.catTotals[top] ?? 0),
                            color: ci.color
                        )
                    } else {
                        StatCardView(label: "Top Category", value: "—", color: AppColor.muted)
                    }
                }
                .padding(.bottom, 20)

                // Monthly chart
                MonthlyChartView(monthlyTotals: stats.monthlyTotals)

                // Expense list
                SectionLabel(sorted.isEmpty ? "Expenses" : "\(sorted.count) Expense\(sorted.count == 1 ? "" : "s")")

                if sorted.isEmpty {
                    Text("Tap Scan Receipt above\nto add your first expense!")
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(sorted) { exp in
                            ExpenseRowView(
                                expense: exp,
                                onPress: onExpensePress,
                                onDelete: onDeletePress
                            )
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 90)  // tabbar clearance
        }
        .refreshable { await onRefresh() }
        .background(Color.clear)
    }
}

// MARK: - Animated flash wrapper

private struct AnimatingFlash: View {
    let expense: Expense?
    var body: some View {
        ZStack {
            if expense != nil {
                FlashResultView(expense: expense)
            }
        }
        .animation(.spring(response: 0.35), value: expense?.id)
    }
}

// MARK: - Scan button

struct ScanButtonView: View {
    var onPress: () -> Void
    var body: some View {
        Button(action: { Haptics.light(); onPress() }) {
            HStack(spacing: 12) {
                Text("📷").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Receipt")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(AppColor.accent2)
                    Text("Camera or photo library")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.accent2.opacity(0.7))
                }
                Spacer()
            }
            .padding(18)
            .background(AppColor.accent.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: Radii.xl))
            .shadow(color: AppColor.accent.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading banner

struct LoadingBannerView: View {
    @State private var angle: Double = 0
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.accent)
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing receipt…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColor.text)
                Text("Reading items and categories")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(AppColor.surface)
        .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.accent.opacity(0.25), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
    }
}

// MARK: - Previews

#Preview("Home - With Data") {
    ZStack {
        AppColor.bg.ignoresSafeArea()
        HomeView(
            expenses: previewExpenses,
            stats: previewStats,
            isLoading: false,
            flash: previewExpenses.first,
            onScanPress: {},
            onExpensePress: { _ in },
            onDeletePress: { _ in },
            onRefresh: {}
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Home - Loading") {
    ZStack {
        AppColor.bg.ignoresSafeArea()
        HomeView(
            expenses: [],
            stats: Stats(),
            isLoading: true,
            flash: nil,
            onScanPress: {},
            onExpensePress: { _ in },
            onDeletePress: { _ in },
            onRefresh: {}
        )
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
        merchant: "CVS Pharmacy",
        date: "2022-06-06",
        total: 8.48,
        category: "Gifts",
        items: [
            ExpenseItem(name: "Birthday Card", quantity: 1, price: 8.48),
        ]
    ),
]

private let previewStats = Stats(
    totalSpent: 159.81,
    catTotals: [
        "Pharmacy": 151.33,
        "Gifts": 8.48,
    ],
    catCounts: [
        "Pharmacy": 1,
        "Gifts": 1,
    ],
    monthlyTotals: [
        "2022-06": 8.48,
        "2024-12": 151.33,
    ],
    topCat: "Pharmacy",
    usedCats: ["Pharmacy", "Gifts"],
    thisMonth: "2024-12"
)
