import SwiftUI
import UIKit

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

private let categoryColorByName: [String: String] = [
    "Groceries":     "#2F855A",
    "Dining":        "#C05621",
    "Fast Food":     "#DD6B20",
    "Coffee":        "#6F4E37",
    "Alcohol":       "#7B2CBF",
    "Rent":          "#4C51BF",
    "Housing":       "#0F766E",
    "Mortgage":      "#2B6CB0",
    "Utilities":     "#B7791F",
    "Internet":      "#0EA5A4",
    "Phone":         "#2563EB",
    "Transport":     "#475569",
    "Gas":           "#C2410C",
    "Parking":       "#1D4ED8",
    "Taxi / Uber":   "#65A30D",
    "Flights":       "#0284C7",
    "Hotel":         "#7C3AED",
    "Travel":        "#0891B2",
    "Healthcare":    "#DC2626",
    "Pharmacy":      "#0D9488",
    "Dentist":       "#0EA5E9",
    "Gym":           "#059669",
    "Sports":        "#1E40AF",
    "Outdoor":       "#4D7C0F",
    "Electronics":   "#4338CA",
    "Clothing":      "#C026D3",
    "Shoes":         "#EA580C",
    "Accessories":   "#BE185D",
    "Beauty":        "#DB2777",
    "Skincare":      "#E11D48",
    "Haircare":      "#92400E",
    "Shopping":      "#A21CAF",
    "Home & Garden": "#15803D",
    "Furniture":     "#8B5E3C",
    "Cleaning":      "#0369A1",
    "Pets":          "#F97316",
    "Kids":          "#CA8A04",
    "Baby":          "#FB7185",
    "Education":     "#1D4ED8",
    "Books":         "#7C2D12",
    "Streaming":     "#BE123C",
    "Gaming":        "#7E22CE",
    "Entertainment": "#C026D3",
    "Subscriptions": "#4F46E5",
    "Office":        "#334155",
    "Gifts":         "#B91C1C",
    "Charity":       "#E11D48",
    "Insurance":     "#0369A1",
    "Taxes":         "#78716C",
    "Other":         "#6B7280",
]

private let fallbackCategoryPalette: [String] = [
    "#2563EB", "#7C3AED", "#DB2777", "#DC2626", "#EA580C",
    "#CA8A04", "#65A30D", "#059669", "#0891B2", "#0F766E",
    "#4F46E5", "#BE185D", "#C05621", "#0369A1", "#475569"
]

private func categoryColorHex(for name: String) -> String {
    if let color = categoryColorByName[name] {
        return color
    }

    let seed = name.unicodeScalars.reduce(0) { (($0 * 31) + Int($1.value)) % 9973 }
    return fallbackCategoryPalette[seed % fallbackCategoryPalette.count]
}

let allCategories: [String: CategoryInfo] = Dictionary(
    uniqueKeysWithValues: categoryEmojiByName.map { name, emoji in
        (name, .init(emoji: emoji, hexColor: categoryColorHex(for: name)))
    }
)

let allCategoryNames: [String] = Array(allCategories.keys)

func categoryInfo(for name: String) -> CategoryInfo {
    allCategories[name] ?? allCategories["Other"]!
}

func localizedCategoryInfoName(for name: String) -> String {
    localizedCategoryName(validCategory(name))
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
