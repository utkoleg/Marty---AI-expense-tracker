import Foundation

struct ExchangeRateQuote: Sendable {
    let from: String
    let to: String
    let rate: Double
    let fetchedAt: String
    let effectiveAt: String?
}

enum ExchangeRateError: LocalizedError {
    case invalidResponse
    case unsupportedCurrencyPair(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return loc("Could not load exchange rates.", "Не удалось загрузить курсы валют.")
        case .unsupportedCurrencyPair(let from, let to):
            return loc(
                "Exchange rate is unavailable for \(from) -> \(to).",
                "Курс для \(from) -> \(to) недоступен."
            )
        }
    }
}

protocol ExchangeRateProviding: Sendable {
    func latestRate(from: String, to: String) async throws -> ExchangeRateQuote
}

actor ExchangeRateService: ExchangeRateProviding {
    private var cache: [String: ExchangeRateQuote] = [:]

    func latestRate(from: String, to: String) async throws -> ExchangeRateQuote {
        let normalizedFrom = normalizedCurrencyCode(from)
        let normalizedTo = normalizedCurrencyCode(to)

        if normalizedFrom == normalizedTo {
            return ExchangeRateQuote(
                from: normalizedFrom,
                to: normalizedTo,
                rate: 1,
                fetchedAt: ISO8601DateFormatter().string(from: Date()),
                effectiveAt: nil
            )
        }

        let cacheKey = "\(normalizedFrom)->\(normalizedTo)"
        if let cached = cache[cacheKey], !isExpired(cached.fetchedAt) {
            return cached
        }

        let url = URL(string: "https://open.er-api.com/v6/latest/\(normalizedFrom)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExchangeRateError.invalidResponse
        }

        let payload = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)
        guard payload.result == "success",
              let rate = payload.rates[normalizedTo]
        else {
            throw ExchangeRateError.unsupportedCurrencyPair(normalizedFrom, normalizedTo)
        }

        let quote = ExchangeRateQuote(
            from: normalizedFrom,
            to: normalizedTo,
            rate: rate,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            effectiveAt: payload.time_last_update_utc
        )

        cache[cacheKey] = quote
        return quote
    }

    private func isExpired(_ fetchedAt: String) -> Bool {
        guard let fetchedDate = ISO8601DateFormatter().date(from: fetchedAt) else { return true }
        return Date().timeIntervalSince(fetchedDate) > 60 * 60
    }
}

private struct ExchangeRateAPIResponse: Decodable {
    let result: String
    let time_last_update_utc: String?
    let rates: [String: Double]
}
