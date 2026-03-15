import Foundation

// MARK: - ExpenseItem

struct ExpenseItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var quantity: Int
    var price: Double

    init(id: UUID = UUID(), name: String, quantity: Int = 1, price: Double) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
    }

    // Persist without the synthetic `id` so storage is compatible with JS app
    enum CodingKeys: String, CodingKey { case name, quantity, price }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try c.decode(String.self, forKey: .name)
        quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 1
        price = (try? c.decode(Double.self, forKey: .price)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(price, forKey: .price)
    }
}

// MARK: - ExpenseGroup

struct ExpenseGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var category: String
    var items: [ExpenseItem]
    var total: Double

    init(id: UUID = UUID(), category: String, items: [ExpenseItem], total: Double) {
        self.id = id
        self.category = category
        self.items = items
        self.total = total
    }

    enum CodingKeys: String, CodingKey { case category, items, total }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        category = try c.decode(String.self, forKey: .category)
        items = (try? c.decode([ExpenseItem].self, forKey: .items)) ?? []
        total = (try? c.decode(Double.self, forKey: .total)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(category, forKey: .category)
        try c.encode(items, forKey: .items)
        try c.encode(total, forKey: .total)
    }
}

// MARK: - Expense

struct Expense: Codable, Identifiable, Equatable {
    var id: String
    var merchant: String
    var date: String        // YYYY-MM-DD
    var total: Double
    var currency: String
    var convertedTotal: Double?
    var convertedCurrency: String?
    var exchangeRate: Double?
    var exchangeRateUpdatedAt: String?
    var category: String
    var items: [ExpenseItem]
    var notes: String
    var addedAt: String     // ISO8601
    var groups: [ExpenseGroup]?

    init(
        id: String = UUID().uuidString,
        merchant: String,
        date: String,
        total: Double,
        currency: String = currentBaseCurrencyCode(),
        convertedTotal: Double? = nil,
        convertedCurrency: String? = nil,
        exchangeRate: Double? = nil,
        exchangeRateUpdatedAt: String? = nil,
        category: String,
        items: [ExpenseItem],
        notes: String = "",
        addedAt: String = ISO8601DateFormatter().string(from: Date()),
        groups: [ExpenseGroup]? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
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

    var isMultiCategory: Bool { (groups?.count ?? 0) > 1 }
}

// MARK: - ReceiptGroup (raw AI output shape before building an Expense)

struct ReceiptGroup: Codable {
    var merchant: String?
    var date: String?
    var currency: String?
    var notes: String?
    var category: String
    var items: [RawItem]
    var total: Double?

    struct RawItem: Codable {
        var name: String
        var quantity: Double?   // AI may send fractional; we round to Int
        var price: FlexDouble   // AI may send "2.99" or 2.99

        var resolvedPrice: Double { price.value }
        var resolvedQty: Int { Int(quantity ?? 1) }
    }

    // "not_receipt" sentinel
    static let notReceiptKey = "not_receipt"
}

/// Accepts either a JSON number or a string-encoded number for `price`.
struct FlexDouble: Codable {
    let value: Double
    init(_ value: Double) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self), let d = Double(s) { value = d; return }
        value = 0
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}
