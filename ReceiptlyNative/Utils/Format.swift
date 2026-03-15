import Foundation

enum InputLimits {
    static let merchant = 80
    static let itemName = 120
    static let notes = 500
    static let currency = 8
    static let category = 40
    static let maxGroupCount = 24
    static let maxItemsPerGroup = 120
    static let maxQuantity = 999
    static let maxPrice = 999_999.99
}

private let blockedInvisibleScalars: Set<Unicode.Scalar> = [
    "\u{200B}", "\u{200C}", "\u{200D}", "\u{200E}", "\u{200F}",
    "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
    "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}",
    "\u{FEFF}",
]

func sanitizeInlineText(_ raw: String, maxLength: Int) -> String {
    let filtered = String(raw.unicodeScalars.filter { scalar in
        !CharacterSet.controlCharacters.contains(scalar) && !blockedInvisibleScalars.contains(scalar)
    })
    let collapsed = filtered.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    return String(collapsed.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
}

func sanitizeMultilineText(_ raw: String, maxLength: Int) -> String {
    let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let filtered = String(normalized.unicodeScalars.filter { scalar in
        (scalar == "\n" || !CharacterSet.controlCharacters.contains(scalar)) && !blockedInvisibleScalars.contains(scalar)
    })
    let collapsedNewlines = filtered.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    return String(collapsedNewlines.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
}

func sanitizeReceiptDate(_ raw: String) -> String {
    let trimmed = sanitizeInlineText(raw, maxLength: 10)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    guard let date = formatter.date(from: trimmed), formatter.string(from: date) == trimmed else {
        return todayString()
    }
    return trimmed
}

func sanitizeCurrencyCode(_ raw: String?) -> String {
    normalizedCurrencyCode(raw)
}

func sanitizePriceValue(_ raw: Double) -> Double {
    guard raw.isFinite else { return 0 }
    return min(max(raw, 0), InputLimits.maxPrice)
}

func sanitizeQuantityValue(_ raw: Int) -> Int {
    min(max(raw, 1), InputLimits.maxQuantity)
}

func sanitizeCSVCell(_ raw: String) -> String {
    let cleaned = sanitizeInlineText(raw, maxLength: 500)
    guard let first = cleaned.first, "=+-@".contains(first) else { return cleaned }
    return "'" + cleaned
}

// MARK: - Month label (mirrors formatMonth() in format.js)
// Input: "2026-03"  →  Output: "Mar '26"

func formatMonth(_ yyyyMM: String) -> String {
    let parts = yyyyMM.split(separator: "-")
    guard parts.count == 2,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          month >= 1, month <= 12
    else { return yyyyMM }

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = 1

    guard let date = Calendar.current.date(from: components) else { return yyyyMM }

    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate(AppLanguage.current == .english ? "LLL yy" : "LLL yyyy")
    return formatter.string(from: date)
}

// MARK: - Date helpers

func todayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

func currentMonthKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM"
    return f.string(from: Date())
}

func displayReceiptDate(_ raw: String) -> String {
    let sanitized = sanitizeReceiptDate(raw)

    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.calendar = Calendar(identifier: .iso8601)
    parser.timeZone = TimeZone(secondsFromGMT: 0)
    parser.dateFormat = "yyyy-MM-dd"

    guard let date = parser.date(from: sanitized) else { return sanitized }

    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

// MARK: - JSON extraction (mirrors extractJSON() in format.js)
// Finds the first complete JSON array or object in a string.

func extractJSON(from text: String) throws -> Any {
    // Fast path: try the whole string first
    if let data = text.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) {
        return obj
    }

    // Find the outermost JSON boundaries, trimming leading/trailing garbage
    // (e.g. markdown code fences like ```json ... ```)
    let firstBracket = text.firstIndex(of: "[")
    let firstBrace   = text.firstIndex(of: "{")
    let lastBracket  = text.lastIndex(of: "]")
    let lastBrace    = text.lastIndex(of: "}")

    let start: String.Index
    let end: String.Index

    switch (firstBracket, firstBrace) {
    case let (b?, c?): start = min(b, c)
    case let (b?, nil): start = b
    case let (nil, c?): start = c
    default:
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: loc("No JSON found", "JSON не найден")])
    }

    switch (lastBracket, lastBrace) {
    case let (b?, c?): end = max(b, c)
    case let (b?, nil): end = b
    case let (nil, c?): end = c
    default:
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: loc("No JSON found", "JSON не найден")])
    }

    guard start <= end else {
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: loc("No JSON found", "JSON не найден")])
    }

    let trimmed = String(text[start...end])
    guard let data = trimmed.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data)
    else {
        throw NSError(domain: "JSON", code: 1, userInfo: [NSLocalizedDescriptionKey: loc("Invalid JSON", "Некорректный JSON")])
    }
    return obj
}
