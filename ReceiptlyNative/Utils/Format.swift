import Foundation

// MARK: - Currency formatting (mirrors fmt() in format.js)

private let usdFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.currencySymbol = "$"
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    return f
}()

func fmt(_ value: Double) -> String {
    usdFormatter.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
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

    let monthNames = ["Jan","Feb","Mar","Apr","May","Jun",
                      "Jul","Aug","Sep","Oct","Nov","Dec"]
    let shortYear = String(year).suffix(2)
    return "\(monthNames[month - 1]) '\(shortYear)"
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
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "No JSON found"])
    }

    switch (lastBracket, lastBrace) {
    case let (b?, c?): end = max(b, c)
    case let (b?, nil): end = b
    case let (nil, c?): end = c
    default:
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "No JSON found"])
    }

    guard start <= end else {
        throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "No JSON found"])
    }

    let trimmed = String(text[start...end])
    guard let data = trimmed.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data)
    else {
        throw NSError(domain: "JSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
    }
    return obj
}
