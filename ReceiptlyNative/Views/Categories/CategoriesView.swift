import SwiftUI

struct CategoriesView: View {
    let stats: Stats
    var onCategoryPress: (String) -> Void
    var onRefresh: () async -> Void

    private var leadingCategory: String? {
        stats.usedCats.first
    }

    var body: some View {
        List {
            if let leadingCategory {
                Section {
                    CategoriesSummaryCard(stats: stats, featuredCategory: leadingCategory)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }
            }

            Section(stats.usedCats.isEmpty ? "" : loc("All Categories", "Все категории")) {
                if stats.usedCats.isEmpty {
                    EmptyStateView(
                        systemName: "square.grid.2x2",
                        title: loc("No categories yet", "Категорий пока нет"),
                        message: loc(
                            "Categories appear automatically after you save your first receipt.",
                            "Категории появятся автоматически после сохранения первого чека."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(stats.usedCats, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            total: stats.catTotals[category] ?? 0,
                            count: stats.catCounts[category] ?? 0,
                            totalSpent: stats.totalSpent,
                            displayCurrency: stats.displayCurrency,
                            onPress: { onCategoryPress(category) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .refreshable { await onRefresh() }
    }
}

private struct CategoriesSummaryCard: View {
    let stats: Stats
    let featuredCategory: String

    private var featuredInfo: CategoryInfo { categoryInfo(for: featuredCategory) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CategoryIconView(info: featuredInfo, size: 52, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("Categories at a glance", "Категории с первого взгляда"))
                        .font(.headline)
                        .foregroundStyle(AppColor.text)

                    Text(localizedActiveCategoryCountText(stats.usedCats.count))
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                SummaryChip(
                    title: loc("Leading", "Лидер"),
                    value: localizedCategoryName(featuredCategory),
                    systemName: "chart.pie"
                )

                SummaryChip(
                    title: loc("Spent", "Потрачено"),
                    value: fmt(stats.catTotals[featuredCategory] ?? 0, currencyCode: stats.displayCurrency),
                    systemName: "dollarsign.circle"
                )
            }
        }
        .padding(20)
        .cardStyle(fill: AppColor.surface, stroke: AppColor.hairline)
    }
}

private struct CategoryRow: View {
    let category: String
    let total: Double
    let count: Int
    let totalSpent: Double
    let displayCurrency: String
    let onPress: () -> Void

    private var info: CategoryInfo { categoryInfo(for: category) }
    private var progressValue: Double {
        guard totalSpent > 0 else { return 0 }
        return min(max(total / totalSpent, 0), 1)
    }

    var body: some View {
        Button(action: onPress) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CategoryIconView(info: info, size: 44, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedCategoryName(category))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.text)

                        Text(localizedReceiptCountText(count))
                            .font(.footnote)
                            .foregroundStyle(AppColor.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(fmt(total, currencyCode: displayCurrency))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(info.color)

                        Text(localizedPercentOfTotalText(Int(progressValue * 100)))
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }

                ProgressView(value: progressValue)
                    .tint(info.color)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
