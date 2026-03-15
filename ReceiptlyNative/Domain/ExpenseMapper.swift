import Foundation

private func receiptGroupFallbackTotal(_ group: ReceiptGroup) -> Double {
    Array(group.items.prefix(InputLimits.maxItemsPerGroup))
        .compactMap { raw -> Double? in
            let name = sanitizeInlineText(raw.name, maxLength: InputLimits.itemName)
            guard !name.isEmpty else { return nil }
            return sanitizePriceValue(raw.resolvedPrice)
        }
        .reduce(0, +)
}

func mergedReceiptGroupsByCategory(_ groups: [ReceiptGroup]) -> [ReceiptGroup] {
    var mergedByCategory: [String: ReceiptGroup] = [:]
    var order: [String] = []

    for group in groups {
        let categoryKey = validCategory(sanitizeInlineText(group.category, maxLength: InputLimits.category))
        let resolvedTotal = sanitizePriceValue(group.total ?? receiptGroupFallbackTotal(group))

        if var existing = mergedByCategory[categoryKey] {
            existing.items.append(contentsOf: group.items)
            existing.total = sanitizePriceValue((existing.total ?? 0) + resolvedTotal)

            if (existing.merchant ?? "").isEmpty, let merchant = group.merchant, !merchant.isEmpty {
                existing.merchant = merchant
            }
            if (existing.date ?? "").isEmpty, let date = group.date, !date.isEmpty {
                existing.date = date
            }
            if (existing.currency ?? "").isEmpty, let currency = group.currency, !currency.isEmpty {
                existing.currency = currency
            }
            if (existing.notes ?? "").isEmpty, let notes = group.notes, !notes.isEmpty {
                existing.notes = notes
            }

            mergedByCategory[categoryKey] = existing
        } else {
            order.append(categoryKey)
            mergedByCategory[categoryKey] = ReceiptGroup(
                merchant: group.merchant,
                date: group.date,
                currency: group.currency,
                notes: group.notes,
                category: categoryKey,
                items: group.items,
                total: resolvedTotal
            )
        }
    }

    return order.compactMap { mergedByCategory[$0] }
}

func mergedExpenseGroupsByCategory(_ groups: [ExpenseGroup]) -> [ExpenseGroup] {
    var mergedByCategory: [String: ExpenseGroup] = [:]
    var order: [String] = []

    for group in groups {
        let categoryKey = validCategory(sanitizeInlineText(group.category, maxLength: InputLimits.category))

        if var existing = mergedByCategory[categoryKey] {
            existing.items.append(contentsOf: group.items)
            existing.total = sanitizePriceValue(existing.total + group.total)
            mergedByCategory[categoryKey] = existing
        } else {
            order.append(categoryKey)
            mergedByCategory[categoryKey] = ExpenseGroup(
                id: group.id,
                category: categoryKey,
                items: group.items,
                total: sanitizePriceValue(group.total)
            )
        }
    }

    return order.compactMap { mergedByCategory[$0] }
}

func buildExpense(from groups: [ReceiptGroup]) -> Expense {
    precondition(!groups.isEmpty, "buildExpense: groups must not be empty")

    let cappedGroups = Array(mergedReceiptGroupsByCategory(groups).prefix(InputLimits.maxGroupCount))

    let normalized: [ExpenseGroup] = cappedGroups.compactMap { group in
        let items: [ExpenseItem] = Array(group.items.prefix(InputLimits.maxItemsPerGroup)).compactMap { raw in
            let name = sanitizeInlineText(raw.name, maxLength: InputLimits.itemName)
            guard !name.isEmpty else { return nil }

            return ExpenseItem(
                name: name,
                quantity: sanitizeQuantityValue(raw.resolvedQty),
                price: sanitizePriceValue(raw.resolvedPrice)
            )
        }
        guard !items.isEmpty else { return nil }

        let computedTotal = items.reduce(0.0) { $0 + $1.price }
        return ExpenseGroup(
            category: validCategory(sanitizeInlineText(group.category, maxLength: InputLimits.category)),
            items: items,
            total: sanitizePriceValue(group.total ?? computedTotal)
        )
    }

    let first = cappedGroups[0]
    let sanitizedMerchant = sanitizeInlineText(first.merchant ?? "", maxLength: InputLimits.merchant)
    let sanitizedDate = sanitizeReceiptDate(first.date ?? todayString())
    let sanitizedCurrency = sanitizeCurrencyCode(first.currency)
    let sanitizedNotes = sanitizeMultilineText(first.notes ?? "", maxLength: InputLimits.notes)

    guard !normalized.isEmpty else {
        return Expense(
            merchant: sanitizedMerchant,
            date: sanitizedDate,
            total: 0,
            currency: sanitizedCurrency,
            category: "Other",
            items: [],
            notes: sanitizedNotes,
            groups: nil
        )
    }

    let dominant = normalized.max(by: { $0.total < $1.total }) ?? normalized[0]

    return Expense(
        merchant: sanitizedMerchant,
        date: sanitizedDate,
        total: sanitizePriceValue(normalized.reduce(0) { $0 + $1.total }),
        currency: sanitizedCurrency,
        category: validCategory(dominant.category),
        items: normalized.flatMap(\.items),
        notes: sanitizedNotes,
        groups: normalized.count > 1 ? normalized : nil
    )
}

func expenseToGroups(_ expense: Expense) -> [ReceiptGroup] {
    if let groups = expense.groups, !groups.isEmpty {
        return mergedExpenseGroupsByCategory(groups).map { group in
            ReceiptGroup(
                merchant: expense.merchant,
                date: expense.date,
                currency: expense.currency,
                notes: expense.notes,
                category: group.category,
                items: group.items.map { item in
                    .init(name: item.name, quantity: Double(item.quantity), price: FlexDouble(item.price))
                },
                total: group.total
            )
        }
    }

    return [
        ReceiptGroup(
            merchant: expense.merchant,
            date: expense.date,
            currency: expense.currency,
            notes: expense.notes,
            category: expense.category,
            items: expense.items.map { item in
                .init(name: item.name, quantity: Double(item.quantity), price: FlexDouble(item.price))
            },
            total: expense.total
        ),
    ]
}
