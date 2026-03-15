import Foundation

enum BaseCurrencyOption: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case kzt = "KZT"
    case rub = "RUB"
    case gbp = "GBP"
    case jpy = "JPY"
    case tryCurrency = "TRY"
    case cny = "CNY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd:
            return loc("US Dollar ($)", "Доллар США ($)")
        case .eur:
            return loc("Euro (EUR)", "Евро (EUR)")
        case .kzt:
            return loc("Kazakhstani Tenge (₸)", "Казахстанский тенге (₸)")
        case .rub:
            return loc("Russian Ruble (₽)", "Российский рубль (₽)")
        case .gbp:
            return loc("British Pound (£)", "Британский фунт (£)")
        case .jpy:
            return loc("Japanese Yen (¥)", "Японская иена (¥)")
        case .tryCurrency:
            return loc("Turkish Lira (₺)", "Турецкая лира (₺)")
        case .cny:
            return loc("Chinese Yuan (¥)", "Китайский юань (¥)")
        }
    }

    static var current: BaseCurrencyOption {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.baseCurrencyKey) ?? BaseCurrencyOption.usd.rawValue
        return BaseCurrencyOption(rawValue: rawValue) ?? .usd
    }
}

private let currencySymbolOverrides: [String: String] = [
    "USD": "$",
    "EUR": "€",
    "KZT": "₸",
    "RUB": "₽",
    "GBP": "£",
    "JPY": "¥",
    "TRY": "₺",
    "CNY": "¥",
]

func currencySymbol(for code: String?) -> String {
    let normalized = normalizedCurrencyCode(code)
    if let symbol = currencySymbolOverrides[normalized] {
        return symbol
    }

    let formatter = NumberFormatter()
    formatter.locale = appLocale()
    formatter.numberStyle = .currency
    formatter.currencyCode = normalized
    return formatter.currencySymbol ?? normalized
}

func currentBaseCurrencyCode() -> String {
    BaseCurrencyOption.current.rawValue
}

func normalizedCurrencyCode(_ raw: String?) -> String {
    let upper = (raw ?? "").uppercased()
    let letters = upper.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    let cleaned = String(String.UnicodeScalarView(letters))
    return String((cleaned.isEmpty ? currentBaseCurrencyCode() : cleaned).prefix(InputLimits.currency))
}

func currencyDisplayName(_ code: String) -> String {
    let normalized = normalizedCurrencyCode(code)
    if let option = BaseCurrencyOption(rawValue: normalized) {
        return option.displayName
    }
    return normalized
}

private func makeCurrencyFormatter(currencyCode: String) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.locale = appLocale()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode
    formatter.currencySymbol = currencySymbol(for: currencyCode)
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter
}

func fmt(_ value: Double, currencyCode: String? = nil) -> String {
    let normalized = normalizedCurrencyCode(currencyCode)
    let formatter = makeCurrencyFormatter(currencyCode: normalized)
    return formatter.string(from: NSNumber(value: value)) ?? "\(normalized) \(String(format: "%.2f", value))"
}

func formatConvertedAmount(
    originalAmount: Double,
    originalCurrency: String,
    convertedAmount: Double?,
    convertedCurrency: String?
) -> String {
    let originalCode = normalizedCurrencyCode(originalCurrency)
    guard let convertedAmount,
          let convertedCurrency
    else {
        return fmt(originalAmount, currencyCode: originalCode)
    }

    let convertedCode = normalizedCurrencyCode(convertedCurrency)
    guard convertedCode != originalCode else {
        return fmt(originalAmount, currencyCode: originalCode)
    }

    return "\(fmt(convertedAmount, currencyCode: convertedCode)) (\(fmt(originalAmount, currencyCode: originalCode)))"
}

extension Expense {
    func convertedAmount(for originalAmount: Double, baseCurrency: String = currentBaseCurrencyCode()) -> Double? {
        let normalizedBase = normalizedCurrencyCode(baseCurrency)
        let originalCode = normalizedCurrencyCode(currency)

        if originalCode == normalizedBase {
            return originalAmount
        }

        guard let convertedCurrency else {
            return nil
        }

        let normalizedConvertedCurrency = normalizedCurrencyCode(convertedCurrency)
        guard normalizedConvertedCurrency == normalizedBase else { return nil }

        if originalAmount == total, let convertedTotal {
            return convertedTotal
        }

        guard let exchangeRate else { return nil }
        return sanitizePriceValue(originalAmount * exchangeRate)
    }

    func displayedBaseAmount(for originalAmount: Double, baseCurrency: String = currentBaseCurrencyCode()) -> Double? {
        if let converted = convertedAmount(for: originalAmount, baseCurrency: baseCurrency) {
            return converted
        }

        return normalizedCurrencyCode(currency) == normalizedCurrencyCode(baseCurrency) ? originalAmount : nil
    }

    func displayTotal(for baseCurrency: String = currentBaseCurrencyCode()) -> Double {
        displayedBaseAmount(for: total, baseCurrency: baseCurrency) ?? total
    }

    func displayAmountText(for originalAmount: Double, baseCurrency: String = currentBaseCurrencyCode()) -> String {
        formatConvertedAmount(
            originalAmount: originalAmount,
            originalCurrency: currency,
            convertedAmount: convertedAmount(for: originalAmount, baseCurrency: baseCurrency),
            convertedCurrency: baseCurrency
        )
    }

    func usesConvertedAmount(for baseCurrency: String = currentBaseCurrencyCode()) -> Bool {
        let originalCode = normalizedCurrencyCode(currency)
        let baseCode = normalizedCurrencyCode(baseCurrency)
        guard let convertedCurrency else { return false }
        return originalCode != baseCode
            && normalizedCurrencyCode(convertedCurrency) == baseCode
            && (convertedTotal != nil || exchangeRate != nil)
    }
}
