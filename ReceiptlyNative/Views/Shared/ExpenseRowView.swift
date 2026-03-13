import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    var categoryFilter: String? = nil
    var onPress: (Expense) -> Void
    var onDelete: (String) -> Void

    private var cat: CategoryInfo { categoryInfo(for: expense.category) }
    private var isMulti: Bool { (expense.groups?.count ?? 0) > 1 }

    // Filtered display when coming from a category detail screen
    private var filteredGroup: ExpenseGroup? {
        guard let filter = categoryFilter else { return nil }
        return expense.groups?.first { $0.category == filter }
            ?? (expense.category == filter
                ? ExpenseGroup(category: expense.category, items: expense.items, total: expense.total)
                : nil)
    }

    private var displayAmount: Double { filteredGroup?.total ?? expense.total }
    private var displayItemCount: Int { filteredGroup?.items.count ?? expense.items.count }

    private var catLine: String {
        if let filter = categoryFilter {
            let names = filteredGroup?.items.compactMap { $0.name.isEmpty ? nil : $0.name }.joined(separator: ", ") ?? filter
            return "\(expense.date) · \(names)"
        }
        if isMulti, let groups = expense.groups {
            return "\(expense.date) · \(groups.map(\.category).joined(separator: ", "))"
        }
        return "\(expense.date) · \(expense.category)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack(alignment: .bottomTrailing) {
                Text(cat.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(cat.color.opacity(0.094))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if isMulti, let count = expense.groups?.count {
                    Text("+\(count - 1)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(AppColor.accentBadgeText)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(x: 3, y: 3)
                }
            }

            // Merchant + meta
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchant.isEmpty ? "(no merchant)" : expense.merchant)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColor.text)
                    .lineLimit(1)
                Text(catLine)
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Amount + item count
            VStack(alignment: .trailing, spacing: 2) {
                Text(fmt(displayAmount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColor.text)
                Text("\(displayItemCount) item\(displayItemCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(AppColor.muted)
            }

            // Delete
            Button {
                onDelete(expense.id)
            } label: {
                Text("🗑")
                    .font(.system(size: 16))
                    .padding(8)
                    .background(AppColor.dangerSoftFill)
                    .overlay(RoundedRectangle(cornerRadius: Radii.sm).stroke(AppColor.dangerSoftBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
            }
        }
        .padding(14)
        .cardStyle()
        .onTapGesture { onPress(expense) }
    }
}
