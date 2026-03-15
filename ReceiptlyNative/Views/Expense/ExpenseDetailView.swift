import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    let baseCurrency: String
    var categoryFilter: String? = nil
    var onDelete: (String) -> Void
    var onEdit: (Expense) -> Void
    var onCategoryPress: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showFull = false
    @State private var showDeleteConfirm = false

    private var categoryInfoValue: CategoryInfo { categoryInfo(for: expense.category) }
    private var isMultiCategory: Bool { (expense.groups?.count ?? 0) > 1 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ExpenseHeroCard(expense: expense, baseCurrency: baseCurrency)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                if !expense.notes.isEmpty {
                    Section(loc("Notes", "Заметки")) {
                        Text(expense.notes)
                            .font(.body)
                            .foregroundStyle(AppColor.text)
                    }
                }

                if let categoryFilter, !showFull {
                    filteredContent(for: categoryFilter)
                } else {
                    fullContent
                }

                Section {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label {
                            Text(loc("Delete Expense", "Удалить расход"))
                                .foregroundStyle(AppColor.danger)
                        } icon: {
                            Image(systemName: "trash")
                                .foregroundStyle(AppColor.danger)
                        }
                    }
                    .confirmationDialog(loc("Delete expense?", "Удалить расход?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button(loc("Delete", "Удалить"), role: .destructive) {
                            closeThen { onDelete(expense.id) }
                        }
                        Button(loc("Cancel", "Отмена"), role: .cancel) {}
                    } message: {
                        Text(loc("This cannot be undone.", "Это действие нельзя отменить."))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(expense.merchant.isEmpty ? loc("Expense", "Расход") : expense.merchant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Done", "Готово")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("Edit", "Изменить")) {
                        closeThen { onEdit(expense) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filteredContent(for category: String) -> some View {
        let group = expense.groups?.first { $0.category == category }
            ?? ExpenseGroup(category: expense.category, items: expense.items, total: expense.total)

        Section(localizedCategoryName(category)) {
            CategorySummaryButton(
                category: category,
                info: categoryInfo(for: category),
                totalText: expense.displayAmountText(for: group.total, baseCurrency: baseCurrency),
                onPress: onCategoryPress
            )

            if group.items.isEmpty {
                Text(loc("No line items extracted for this category.", "Для этой категории позиции не были извлечены."))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
            } else {
                ForEach(group.items) { item in
                    ExpenseLineItemRow(item: item, currencyCode: expense.currency)
                }
            }
        }

        Section {
            Button(loc("Show Entire Receipt", "Показать весь чек")) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFull = true
                }
            }
        }
    }

    @ViewBuilder
    private var fullContent: some View {
        if expense.items.isEmpty && (expense.groups?.isEmpty != false) {
            Section {
                EmptyStateView(
                    systemName: "tray",
                    title: loc("No line items extracted", "Позиции не извлечены"),
                    message: loc("Try scanning a clearer image if you want line-by-line details.", "Попробуй более четкое фото, если нужны детальные позиции.")
                )
                .listRowBackground(Color.clear)
            }
        } else if isMultiCategory, let groups = expense.groups {
            ForEach(groups, id: \.category) { group in
                Section(localizedCategoryName(group.category)) {
                    CategorySummaryButton(
                        category: group.category,
                        info: categoryInfo(for: group.category),
                        totalText: expense.displayAmountText(for: group.total, baseCurrency: baseCurrency),
                        onPress: onCategoryPress
                    )

                    ForEach(group.items) { item in
                        ExpenseLineItemRow(item: item, currencyCode: expense.currency)
                    }

                    LabeledContent(loc("Subtotal", "Подытог"), value: expense.displayAmountText(for: group.total, baseCurrency: baseCurrency))
                        .font(.subheadline.weight(.semibold))
                }
            }

            Section {
                LabeledContent(loc("Total", "Итого"), value: expense.displayAmountText(for: expense.total, baseCurrency: baseCurrency))
                    .font(.headline.weight(.semibold))
            }
        } else {
            Section(localizedCategoryName(expense.category)) {
                CategorySummaryButton(
                    category: expense.category,
                    info: categoryInfoValue,
                    totalText: expense.displayAmountText(for: expense.total, baseCurrency: baseCurrency),
                    onPress: onCategoryPress
                )

                ForEach(expense.items) { item in
                    ExpenseLineItemRow(item: item, currencyCode: expense.currency)
                }

                LabeledContent(loc("Total", "Итого"), value: expense.displayAmountText(for: expense.total, baseCurrency: baseCurrency))
                    .font(.headline.weight(.semibold))
            }
        }
    }

    private func closeThen(_ action: @escaping () -> Void) {
        dismiss()
        UIActionScheduler.perform(after: UIActionDelay.followUpActionSeconds) {
            action()
        }
    }
}

private struct ExpenseHeroCard: View {
    let expense: Expense
    let baseCurrency: String

    private var isMultiCategory: Bool { (expense.groups?.count ?? 0) > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                if isMultiCategory, let groups = expense.groups {
                    HStack(spacing: 6) {
                        ForEach(groups.prefix(3), id: \.category) { group in
                            CategoryIconView(info: categoryInfo(for: group.category), size: 42, cornerRadius: 14)
                        }
                    }
                } else {
                    CategoryIconView(info: categoryInfo(for: expense.category), size: 52, cornerRadius: 18)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.merchant.isEmpty ? localizedNoMerchantText() : expense.merchant)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.text)

                    Text(displayReceiptDate(expense.date))
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                ExpenseTotalChip(expense: expense, baseCurrency: baseCurrency)

                SummaryChip(
                    title: loc("Items", "Позиции"),
                    value: "\(expense.items.count)",
                    systemName: "shippingbox"
                )
            }
        }
        .padding(20)
        .cardStyle(fill: AppColor.elevated, stroke: AppColor.hairline)
    }
}

private struct ExpenseTotalChip: View {
    let expense: Expense
    let baseCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 14, alignment: .leading)

                Text(loc("Total", "Итого"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(AppColor.muted)

            Text(expense.displayAmountText(for: expense.total, baseCurrency: baseCurrency))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.text)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

private struct CategorySummaryButton: View {
    let category: String
    let info: CategoryInfo
    let totalText: String
    var onPress: ((String) -> Void)? = nil

    var body: some View {
        Button {
            onPress?(category)
        } label: {
            HStack(spacing: 12) {
                CategoryIconView(info: info, size: 40, cornerRadius: 13)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedCategoryName(category))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.text)

                    Text(totalText)
                        .font(.footnote)
                        .foregroundStyle(info.color)
                        .lineLimit(2)
                }

                Spacer()

                if onPress != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onPress == nil)
    }
}

private struct ExpenseLineItemRow: View {
    let item: ExpenseItem
    let currencyCode: String

    var body: some View {
        LabeledContent {
            Text(fmt(item.price, currencyCode: currencyCode))
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.text)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.isEmpty ? localizedUnnamedItemText() : item.name)
                    .font(.body)
                    .foregroundStyle(AppColor.text)

                if item.quantity > 1 {
                    Text(localizedQuantityText(item.quantity))
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }
}
