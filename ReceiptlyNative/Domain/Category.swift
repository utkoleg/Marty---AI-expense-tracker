import SwiftUI

// MARK: - CategoryInfo

struct CategoryInfo {
    let emoji: String
    let hexColor: String

    var color: Color { Color(hex: hexColor) }
    var uiColor: UIColor { UIColor(hex: hexColor) }
}

// MARK: - Category registry

private let categoryEmojiByName: [String: String] = [
    "Groceries":     "🛒",
    "Dining":        "🍽️",
    "Fast Food":     "🍔",
    "Coffee":        "☕",
    "Alcohol":       "🍺",
    "Rent":          "🔑",
    "Housing":       "🏠",
    "Mortgage":      "🏦",
    "Utilities":     "💡",
    "Internet":      "🌐",
    "Phone":         "📞",
    "Transport":     "🚗",
    "Gas":           "⛽",
    "Parking":       "🅿️",
    "Taxi / Uber":   "🚕",
    "Flights":       "🛫",
    "Hotel":         "🏨",
    "Travel":        "✈️",
    "Healthcare":    "💊",
    "Pharmacy":      "💉",
    "Dentist":       "🦷",
    "Gym":           "🏋️",
    "Sports":        "⚽",
    "Outdoor":       "🏕️",
    "Electronics":   "📱",
    "Clothing":      "👕",
    "Shoes":         "👟",
    "Accessories":   "👜",
    "Beauty":        "💄",
    "Skincare":      "🧴",
    "Haircare":      "✂️",
    "Shopping":      "🛍️",
    "Home & Garden": "🛋️",
    "Furniture":     "🪑",
    "Cleaning":      "🧹",
    "Pets":          "🐾",
    "Kids":          "🧸",
    "Baby":          "👶",
    "Education":     "📚",
    "Books":         "📖",
    "Streaming":     "📺",
    "Gaming":        "🎮",
    "Entertainment": "🎬",
    "Subscriptions": "🔁",
    "Office":        "🖥️",
    "Gifts":         "🎁",
    "Charity":       "❤️",
    "Insurance":     "🛡️",
    "Taxes":         "🧾",
    "Other":         "📌",
]

private let iconCategoryPalette: [String] = [
    "#0a5a3e", "#0d6a49", "#117957", "#169069",
    "#1ea87a", "#0d7f59", "#2d4740", "#426057",
    "#0b1611", "#18241f", "#22322c", "#31453d"
]

private func iconCategoryHex(for name: String) -> String {
    let seed = name.unicodeScalars.reduce(0) { (($0 * 31) + Int($1.value)) % 9973 }
    return iconCategoryPalette[seed % iconCategoryPalette.count]
}

let allCategories: [String: CategoryInfo] = Dictionary(
    uniqueKeysWithValues: categoryEmojiByName.map { name, emoji in
        (name, .init(emoji: emoji, hexColor: iconCategoryHex(for: name)))
    }
)

let allCategoryNames: [String] = Array(allCategories.keys)

func categoryInfo(for name: String) -> CategoryInfo {
    allCategories[name] ?? allCategories["Other"]!
}

func validCategory(_ name: String) -> String {
    allCategories[name] != nil ? name : "Other"
}

// MARK: - Color(hex:) extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
