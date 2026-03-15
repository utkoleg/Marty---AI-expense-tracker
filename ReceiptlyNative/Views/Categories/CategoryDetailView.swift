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
    var onExpensePress: (Expense, String) -> Void
    var onDeletePress: (String) -> Void

    private var categoryInfoValue: CategoryInfo { categoryInfo(for: category) }

    private var categoryExpenses: [Expense] {
        expenses.filter { expense in
            expense.category == category || expense.groups?.contains { $0.category == category } == true
        }
    }

    private var rows: [CatDetailRow] {
        categoryExpenses.map { expense in
            let items: [ExpenseItem]
            if let groups = expense.groups {
                items = groups.first { $0.category == category }?.items ?? []
            } else {
                items = expense.items
            }
            let total = items.reduce(0) { $0 + $1.price }
            return CatDetailRow(id: expense.id, expense: expense, items: items, total: total)
        }
        .sorted { $0.expense.date > $1.expense.date }
    }

    private var categoryTotal: Double {
        rows.reduce(0) { partial, row in
            partial + (row.expense.convertedAmount(for: row.total) ?? row.total)
        }
    }

    private var totalItems: Int {
        rows.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        List {
            Section {
                CategorySummaryCard(
                    category: category,
                    info: categoryInfoValue,
                    total: categoryTotal,
                    itemCount: totalItems,
                    receiptCount: rows.count
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
            }

            Section(rows.isEmpty ? "" : loc("Expenses", "Расходы")) {
                if rows.isEmpty {
                    EmptyStateView(
                        systemName: "tray",
                        title: loc("Nothing here yet", "Пока пусто"),
                        message: loc(
                            "Receipts assigned to this category will appear here.",
                            "Здесь появятся чеки, относящиеся к этой категории."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(rows) { row in
                        ExpenseRowView(
                            expense: row.expense,
                            categoryFilter: category,
                            onPress: { expense in
                                onExpensePress(expense, category)
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDeletePress(row.expense.id)
                            } label: {
                                Label(loc("Delete", "Удалить"), systemImage: "trash")
                            }
                            .tint(AppColor.danger)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.bg)
        .navigationTitle(localizedCategoryName(category))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CategorySummaryCard: View {
    let category: String
    let info: CategoryInfo
    let total: Double
    let itemCount: Int
    let receiptCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                CategoryIconView(info: info, size: 58, cornerRadius: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedCategoryName(category))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.text)

                    Text(localizedReceiptCountText(receiptCount))
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                SummaryChip(
                    title: loc("Spent", "Потрачено"),
                    value: fmt(total),
                    systemName: "dollarsign.circle"
                )

                SummaryChip(
                    title: loc("Items", "Позиции"),
                    value: "\(itemCount)",
                    systemName: "shippingbox"
                )
            }
        }
        .padding(20)
        .cardStyle(fill: AppColor.surface, stroke: AppColor.hairline)
    }
}
