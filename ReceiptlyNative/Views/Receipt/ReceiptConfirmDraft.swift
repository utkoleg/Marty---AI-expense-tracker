import Foundation

enum ReceiptDraftValidation {
    static func parsePrice(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    static func isValidDate(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = formatter.date(from: trimmed) else { return false }
        return formatter.string(from: date) == trimmed
    }

    static func itemNameMessage(for item: EditableItem) -> String? {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? loc("Enter item name", "Введите название позиции") : nil
    }

    static func itemPriceMessage(for item: EditableItem) -> String? {
        let trimmed = item.price.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return loc("Enter price", "Введите цену") }
        return parsePrice(trimmed) == nil ? loc("Invalid price", "Некорректная цена") : nil
    }
}

struct EditableItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var price: String
    var quantity: Int

    init(name: String, price: Double, quantity: Int = 1) {
        self.name = name
        self.price = String(format: "%.2f", price)
        self.quantity = quantity
    }
}

struct EditableGroup: Identifiable, Equatable {
    var id: UUID = UUID()
    var category: String
    var items: [EditableItem]

    var total: Double {
        items.reduce(0) { partial, item in
            partial + (ReceiptDraftValidation.parsePrice(item.price) ?? 0)
        }
    }
}

struct ReceiptDraft: Equatable {
    var merchant: String
    var date: String
    var currency: String?
    var notes: String?
    var groups: [EditableGroup]

    init(groups: [ReceiptGroup]) {
        let mergedGroups = mergedReceiptGroupsByCategory(groups)
        merchant = mergedGroups.first?.merchant ?? ""
        date = sanitizeReceiptDate(mergedGroups.first?.date ?? todayString())
        currency = sanitizeCurrencyCode(mergedGroups.first?.currency)
        notes = mergedGroups.first?.notes
        self.groups = mergedGroups.map { group in
            EditableGroup(
                category: validCategory(group.category),
                items: group.items.map { item in
                    EditableItem(
                        name: item.name,
                        price: item.resolvedPrice,
                        quantity: item.resolvedQty
                    )
                }
            )
        }
    }

    var hasAnyItems: Bool {
        groups.contains { !$0.items.isEmpty }
    }

    var total: Double {
        groups.reduce(0) { $0 + $1.total }
    }

    var merchantValidationMessage: String? {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? loc("Enter merchant name", "Введите название магазина") : nil
    }

    var dateValidationMessage: String? {
        let trimmed = date.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return loc("Enter date", "Введите дату") }
        return ReceiptDraftValidation.isValidDate(trimmed) ? nil : loc("Use YYYY-MM-DD", "Используй ГГГГ-ММ-ДД")
    }

    var hasValidationErrors: Bool {
        merchantValidationMessage != nil ||
        dateValidationMessage != nil ||
        groups.contains { group in
            group.items.contains { item in
                ReceiptDraftValidation.itemNameMessage(for: item) != nil ||
                    ReceiptDraftValidation.itemPriceMessage(for: item) != nil
            }
        }
    }

    mutating func addGroup() -> UUID {
        let newGroup = EditableGroup(category: "Other", items: [EditableItem(name: "", price: 0)])
        groups.append(newGroup)
        return newGroup.id
    }

    mutating func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
    }

    mutating func setCategory(_ category: String, for groupID: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let normalizedCategory = validCategory(sanitizeInlineText(category, maxLength: InputLimits.category))

        if let existingIndex = groups.firstIndex(where: { $0.id != groupID && $0.category == normalizedCategory }) {
            groups[existingIndex].items.append(contentsOf: groups[index].items)
            groups.remove(at: index)
            return
        }

        groups[index].category = normalizedCategory
    }

    func selectedCategory(for groupID: UUID) -> String? {
        groups.first(where: { $0.id == groupID })?.category
    }

    mutating func moveItem(_ itemID: UUID, to targetGroupID: UUID) -> Bool {
        guard let sourceGroupIndex = groups.firstIndex(where: { group in
            group.items.contains(where: { $0.id == itemID })
        }),
        let sourceItemIndex = groups[sourceGroupIndex].items.firstIndex(where: { $0.id == itemID }),
        groups[sourceGroupIndex].id != targetGroupID
        else {
            return false
        }

        var nextGroups = groups
        let movedItem = nextGroups[sourceGroupIndex].items.remove(at: sourceItemIndex)

        guard let targetGroupIndex = nextGroups.firstIndex(where: { $0.id == targetGroupID }) else {
            return false
        }

        nextGroups[targetGroupIndex].items.append(movedItem)
        nextGroups.removeAll { $0.items.isEmpty }
        groups = nextGroups
        return true
    }

    func buildReceiptGroups() -> [ReceiptGroup] {
        let rawGroups = groups
            .filter { !$0.items.isEmpty }
            .map { group in
                ReceiptGroup(
                    merchant: sanitizeInlineText(merchant, maxLength: InputLimits.merchant),
                    date: sanitizeReceiptDate(date),
                    currency: sanitizeCurrencyCode(currency),
                    notes: sanitizeMultilineText(notes ?? "", maxLength: InputLimits.notes),
                    category: validCategory(sanitizeInlineText(group.category, maxLength: InputLimits.category)),
                    items: group.items.map { item in
                        ReceiptGroup.RawItem(
                            name: sanitizeInlineText(item.name, maxLength: InputLimits.itemName),
                            quantity: Double(sanitizeQuantityValue(item.quantity)),
                            price: FlexDouble(sanitizePriceValue(ReceiptDraftValidation.parsePrice(item.price) ?? 0))
                        )
                    },
                    total: sanitizePriceValue(group.total)
                )
            }

        return mergedReceiptGroupsByCategory(rawGroups)
    }
}
