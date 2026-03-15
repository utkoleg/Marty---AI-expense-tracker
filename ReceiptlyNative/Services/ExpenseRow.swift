import Foundation

struct ExpenseRow: Codable, Equatable, Sendable {
    var id: String
    var userID: String?
    var merchant: String
    var expenseDate: String
    var total: Double
    var currency: String
    var convertedTotal: Double?
    var convertedCurrency: String?
    var exchangeRate: Double?
    var exchangeRateUpdatedAt: String?
    var category: String
    var items: [ExpenseItemRow]
    var notes: String
    var addedAt: String
    var groups: [ExpenseGroupRow]?

    init(
        id: String,
        userID: String? = nil,
        merchant: String,
        expenseDate: String,
        total: Double,
        currency: String,
        convertedTotal: Double? = nil,
        convertedCurrency: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateUpdatedAt: String? = nil,
        category: String,
        items: [ExpenseItemRow],
        notes: String,
        addedAt: String,
        groups: [ExpenseGroupRow]? = nil
    ) {
        self.id = id
        self.userID = userID
        self.merchant = merchant
        self.expenseDate = expenseDate
        self.total = total
        self.currency = currency
        self.convertedTotal = convertedTotal
        self.convertedCurrency = convertedCurrency
        self.exchangeRate = exchangeRate
        self.exchangeRateUpdatedAt = exchangeRateUpdatedAt
        self.category = category
        self.items = items
        self.notes = notes
        self.addedAt = addedAt
        self.groups = groups
    }

    init(expense: Expense, userID: String? = nil) {
        self.init(
            id: expense.id,
            userID: userID,
            merchant: expense.merchant,
            expenseDate: expense.date,
            total: expense.total,
            currency: expense.currency,
            convertedTotal: expense.convertedTotal,
            convertedCurrency: expense.convertedCurrency,
            exchangeRate: expense.exchangeRate,
            exchangeRateUpdatedAt: expense.exchangeRateUpdatedAt,
            category: expense.category,
            items: expense.items.map(ExpenseItemRow.init),
            notes: expense.notes,
            addedAt: expense.addedAt,
            groups: expense.groups?.map(ExpenseGroupRow.init)
        )
    }

    func asExpense() -> Expense {
        Expense(
            id: id,
            merchant: merchant,
            date: expenseDate,
            total: total,
            currency: currency,
            convertedTotal: convertedTotal,
            convertedCurrency: convertedCurrency,
            exchangeRate: exchangeRate,
            exchangeRateUpdatedAt: exchangeRateUpdatedAt,
            category: category,
            items: items.map { $0.asExpenseItem() },
            notes: notes,
            addedAt: addedAt,
            groups: groups?.map { $0.asExpenseGroup() }
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case merchant
        case expenseDate = "expense_date"
        case total
        case currency
        case convertedTotal = "converted_total"
        case convertedCurrency = "converted_currency"
        case exchangeRate = "exchange_rate"
        case exchangeRateUpdatedAt = "exchange_rate_updated_at"
        case category
        case items
        case notes
        case addedAt = "added_at"
        case groups
    }
}

struct ExpenseItemRow: Codable, Equatable, Sendable {
    var name: String
    var quantity: Int
    var price: Double

    init(name: String, quantity: Int, price: Double) {
        self.name = name
        self.quantity = quantity
        self.price = price
    }

    init(item: ExpenseItem) {
        self.init(name: item.name, quantity: item.quantity, price: item.price)
    }

    func asExpenseItem() -> ExpenseItem {
        ExpenseItem(name: name, quantity: quantity, price: price)
    }
}

struct ExpenseGroupRow: Codable, Equatable, Sendable {
    var category: String
    var items: [ExpenseItemRow]
    var total: Double

    init(category: String, items: [ExpenseItemRow], total: Double) {
        self.category = category
        self.items = items
        self.total = total
    }

    init(group: ExpenseGroup) {
        self.init(
            category: group.category,
            items: group.items.map(ExpenseItemRow.init),
            total: group.total
        )
    }

    func asExpenseGroup() -> ExpenseGroup {
        ExpenseGroup(
            category: category,
            items: items.map { $0.asExpenseItem() },
            total: total
        )
    }
}
