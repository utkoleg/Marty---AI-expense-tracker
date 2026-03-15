import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    var categoryFilter: String? = nil
    var baseCurrency: String = currentBaseCurrencyCode()
    var onPress: (Expense) -> Void

    private var cat: CategoryInfo { categoryInfo(for: categoryFilter ?? expense.category) }
    private var displayGroups: [ExpenseGroup] { mergedExpenseGroupsByCategory(expense.groups ?? []) }
    private var isMulti: Bool { displayGroups.count > 1 }
    private var extraCategoryCount: Int { max(displayGroups.count - 1, 0) }

    private var filteredGroup: ExpenseGroup? {
        guard let filter = categoryFilter else { return nil }
        return displayGroups.first { $0.category == filter }
            ?? (expense.category == filter
                ? ExpenseGroup(category: expense.category, items: expense.items, total: expense.total)
                : nil)
    }

    private var displayAmount: Double { filteredGroup?.total ?? expense.total }
    private var displayItemCount: Int { filteredGroup?.items.count ?? expense.items.count }

    private var catLine: String {
        let dateText = displayReceiptDate(expense.date)

        if let filter = categoryFilter {
            let names = filteredGroup?.items
                .compactMap { $0.name.isEmpty ? nil : $0.name }
                .joined(separator: ", ")
            return "\(dateText) · \(names?.isEmpty == false ? names! : localizedCategoryName(filter))"
        }

        if isMulti {
            return "\(dateText) · \(localizedCategoryList(displayGroups.map(\.category)))"
        }

        return "\(dateText) · \(localizedCategoryName(expense.category))"
    }

    var body: some View {
        Button(action: { onPress(expense) }) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    CategoryIconView(info: cat, size: 42, cornerRadius: 14)

                    if isMulti {
                        Text("+\(extraCategoryCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColor.accentBadgeText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColor.accent, in: Capsule())
                            .offset(x: 5, y: 5)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.merchant.isEmpty ? localizedNoMerchantText() : expense.merchant)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)

                    Text(catLine)
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.displayAmountText(for: displayAmount, baseCurrency: baseCurrency))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.72)

                    Text(localizedItemCountText(displayItemCount))
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
