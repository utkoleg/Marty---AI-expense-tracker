import SwiftUI

struct CatDetailRow: Identifiable {
    let id: String
    let expense: Expense
    let items: [ExpenseItem]
    let total: Double
}

struct CategoryDetailView: View {
    let category: String
    let expenses: [Expense]
    var onBack: () -> Void
    var onExpensePress: (Expense, String) -> Void
    var onDeletePress: (String) -> Void

    private var ci: CategoryInfo { categoryInfo(for: category) }

    private var catExpenses: [Expense] {
        expenses.filter { e in
            e.category == category || e.groups?.contains { $0.category == category } == true
        }
    }

    private var rows: [CatDetailRow] {
        catExpenses.map { e in
            let items: [ExpenseItem]
            if let groups = e.groups {
                items = groups.first { $0.category == category }?.items ?? []
            } else {
                items = e.items
            }
            let total = items.reduce(0) { $0 + $1.price }
            return CatDetailRow(id: e.id, expense: e, items: items, total: total)
        }
    }

    private var catTotal: Double { rows.reduce(0) { $0 + $1.total } }
    private var totalItems: Int  { rows.reduce(0) { $0 + $1.items.count } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Text("‹").font(.system(size: 16))
                        Text("Back")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.text)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .cardStyle()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)

                HStack(spacing: 16) {
                    Text(ci.emoji).font(.system(size: 34))
                        .frame(width: 64, height: 64)
                        .background(ci.color.opacity(0.094))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category).font(.system(size: 28, weight: .black)).foregroundColor(AppColor.text)
                        HStack(spacing: 4) {
                            Text("\(totalItems) item\(totalItems == 1 ? "" : "s") ·")
                                .font(.system(size: 13)).foregroundColor(AppColor.muted)
                            Text(fmt(catTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(ci.color)
                        }
                    }
                }
                .padding(.bottom, 20)

                VStack(spacing: 10) {
                    StatCardView(label: "Total", value: fmt(catTotal), color: ci.color)
                    HStack(spacing: 10) {
                        StatCardView(label: "Avg",
                                     value: fmt(rows.isEmpty ? 0 : catTotal / Double(rows.count)),
                                     color: AppColor.muted)
                        StatCardView(label: "Count", value: "\(rows.count)", color: AppColor.success)
                    }
                }
                .padding(.bottom, 20)

                SectionLabel("\(rows.count) Expense\(rows.count == 1 ? "" : "s")")

                LazyVStack(spacing: 8) {
                    ForEach(rows) { row in
                        CatExpenseRow(
                            row: row, ci: ci, category: category,
                            onPress: { onExpensePress(row.expense, category) },
                            onDelete: { onDeletePress(row.expense.id) }
                        )
                    }
                }
            }
            .padding(16).padding(.bottom, 90)
        }
        .background(Color.clear)
    }
}

private struct CatExpenseRow: View {
    let row: CatDetailRow
    let ci: CategoryInfo
    let category: String
    var onPress: () -> Void
    var onDelete: () -> Void

    private var title: String {
        row.items.count == 1 ? row.items[0].name : row.expense.merchant
    }
    private var subtitle: String {
        if row.items.count == 1 { return "\(row.expense.date) · \(row.expense.merchant)" }
        let names = row.items.compactMap { $0.name.isEmpty ? nil : $0.name }.joined(separator: ", ")
        return "\(row.expense.date) · \(names)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(ci.emoji).font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(ci.color.opacity(0.094))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColor.text).lineLimit(1)
                Text(subtitle).font(.system(size: 12)).foregroundColor(AppColor.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(fmt(row.total)).font(.system(size: 16, weight: .bold)).foregroundColor(AppColor.text)
                Text("\(row.items.count) item\(row.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundColor(AppColor.muted)
            }

            Button(action: onDelete) {
                Text("🗑").font(.system(size: 16)).padding(8)
                    .background(AppColor.dangerSoftFill)
                    .overlay(RoundedRectangle(cornerRadius: Radii.sm).stroke(AppColor.dangerSoftBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
            }
        }
        .padding(14).cardStyle().onTapGesture { onPress() }
    }
}
