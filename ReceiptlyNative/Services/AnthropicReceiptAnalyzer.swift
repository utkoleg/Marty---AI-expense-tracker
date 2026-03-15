import Foundation
import UIKit

enum AnalyzerError: LocalizedError {
    case noAPIKey
    case notAReceipt
    case httpError(Int, String)
    case timeout
    case cancelled
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return loc(
                "No API key configured. Add your Anthropic key in Settings.",
                "API-ключ не настроен. Добавь ключ Anthropic в настройках."
            )
        case .notAReceipt:
            return loc("Not a receipt", "Это не чек")
        case .httpError(let statusCode, let message):
            return loc("API error \(statusCode): \(message)", "Ошибка API \(statusCode): \(message)")
        case .timeout:
            return loc(
                "Request timed out. Check your connection and try again.",
                "Время запроса истекло. Проверь соединение и попробуй снова."
            )
        case .cancelled:
            return loc("Cancelled", "Отменено")
        case .parseError(let message):
            return loc("Could not read receipt: \(message)", "Не удалось прочитать чек: \(message)")
        }
    }
}

struct StagedImage: Identifiable {
    let id: UUID
    let uiImage: UIImage
    var mediaType: String = "image/jpeg"
    var b64: String { uiImage.jpegData(compressionQuality: 0.7).map { $0.base64EncodedString() } ?? "" }

    init(uiImage: UIImage, mediaType: String = "image/jpeg") {
        self.id = UUID()
        self.uiImage = uiImage
        self.mediaType = mediaType
    }
}

protocol ReceiptAnalyzing: Sendable {
    func analyze(images: [StagedImage], timeoutSeconds: Double) async throws -> [ReceiptGroup]
}

private let prompt = """
Is this a receipt/invoice/bill/financial document?
No→ {"not_receipt":true}
Yes→ JSON array where EACH category gets its OWN object. If items span 3 categories, output 3 objects. No markdown:
[{"merchant":"","date":"YYYY-MM-DD","total":0,"currency":"ISO_4217_CODE","category":"","items":[{"name":"","quantity":1,"price":0}],"notes":""}]
Rules: One object per category. Group total=sum of its items. Tax/shipping→add to largest group.
Categories: \(allCategoryNames.joined(separator: ", "))
Use the actual receipt currency. Examples: USD, EUR, KZT, RUB, GBP.
Categorize by item type not store name:
- protein/creatine/BCAAs/supplements→Gym
- workout gear/gym clothes→Gym
- medicine/vitamins/pills/OTC drugs→Pharmacy
- prescriptions/lab tests→Healthcare
- cookware/spatulas/utensils→Home & Garden
- sports equipment/shoes→Sports
- food delivery→Fast Food
- fresh food/produce/pantry→Groceries
- clothing/apparel/shoes→Clothing
- Only use Shopping if item truly doesn't fit any other category
Extract ALL line items. Never collapse multiple categories into one.
"""

enum APIKeyStore {
    private static let key = "receiptly_anthropic_key"

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var hasKey: Bool { !apiKey.isEmpty }
}

actor AnthropicReceiptAnalyzer: ReceiptAnalyzing {
    func analyze(images: [StagedImage], timeoutSeconds: Double = 60) async throws -> [ReceiptGroup] {
        let key = APIKeyStore.apiKey
        guard !key.isEmpty else { throw AnalyzerError.noAPIKey }

        let promptText: String
        if images.count > 1 {
            promptText = "These \(images.count) images are different pages/parts of the SAME receipt. "
                + "Treat them as one document and extract all items across all pages.\n\n" + prompt
        } else {
            promptText = prompt
        }

        let imageBlocks: [[String: Any]] = images.map { image in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mediaType,
                    "data": image.b64,
                ],
            ]
        }
        let content: [[String: Any]] = imageBlocks + [["type": "text", "text": promptText]]

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 4000,
            "stream": true,
            "messages": [["role": "user", "content": content]],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = timeoutSeconds

        let (asyncBytes, response) = try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
            group.addTask {
                try await URLSession.shared.bytes(for: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw AnalyzerError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnalyzerError.parseError(loc("No HTTP response", "Нет ответа от сервера"))
        }
        guard http.statusCode == 200 else {
            throw AnalyzerError.httpError(http.statusCode, "HTTP \(http.statusCode)")
        }

        var accumulated = ""
        var sseBuffer = ""

        for try await line in asyncBytes.lines {
            if Task.isCancelled { throw AnalyzerError.cancelled }

            sseBuffer += line + "\n"

            let lines = sseBuffer.split(separator: "\n", omittingEmptySubsequences: false)
            for rawLine in lines.dropLast() {
                let currentLine = String(rawLine)
                guard currentLine.hasPrefix("data: ") else { continue }
                let payload = String(currentLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                if let eventType = event["type"] as? String {
                    if eventType == "content_block_delta",
                       let delta = event["delta"] as? [String: Any],
                       delta["type"] as? String == "text_delta",
                       let text = delta["text"] as? String {
                        accumulated += text
                    } else if eventType == "error" {
                        let message = (event["error"] as? [String: Any])?["message"] as? String
                            ?? loc("Stream error", "Ошибка потока")
                        throw AnalyzerError.parseError(message)
                    }
                }
            }
            sseBuffer = lines.last.map(String.init) ?? ""

            if let result = try? parseGroups(from: accumulated) {
                return result
            }
        }

        return try parseGroups(from: accumulated)
    }

    private func parseGroups(from text: String) throws -> [ReceiptGroup] {
        let json = try extractJSON(from: text)

        if let obj = json as? [String: Any], obj["not_receipt"] as? Bool == true {
            throw AnalyzerError.notAReceipt
        }

        guard let array = json as? [[String: Any]] else {
            if let obj = json as? [String: Any] {
                return [try decodeGroup(from: obj)]
            }
            throw AnalyzerError.parseError(loc("Unexpected JSON shape", "Неожиданная структура JSON"))
        }
        return try array.map { try decodeGroup(from: $0) }
    }

    private func decodeGroup(from obj: [String: Any]) throws -> ReceiptGroup {
        let data = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(ReceiptGroup.self, from: data)
    }
}
