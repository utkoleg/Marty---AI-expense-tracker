import Foundation
import UIKit

// MARK: - Errors

enum AnalyzerError: LocalizedError {
    case noAPIKey
    case notAReceipt
    case httpError(Int, String)
    case timeout
    case cancelled
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:        return "No API key configured. Add your Anthropic key in Settings."
        case .notAReceipt:     return "Not a receipt"
        case .httpError(let s, let m): return "API error \(s): \(m)"
        case .timeout:         return "Request timed out. Check your connection and try again."
        case .cancelled:       return "Cancelled"
        case .parseError(let m): return "Could not read receipt: \(m)"
        }
    }
}

// MARK: - Staged image

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

// MARK: - Prompt  (identical to receiptAnalyzer.js)

private let prompt = """
Is this a receipt/invoice/bill/financial document?
No→ {"not_receipt":true}
Yes→ JSON array where EACH category gets its OWN object. If items span 3 categories, output 3 objects. No markdown:
[{"merchant":"","date":"YYYY-MM-DD","total":0,"currency":"USD","category":"","items":[{"name":"","quantity":1,"price":0}],"notes":""}]
Rules: One object per category. Group total=sum of its items. Tax/shipping→add to largest group.
Categories: \(allCategoryNames.joined(separator: ", "))
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

// MARK: - API key storage (Keychain via UserDefaults for simplicity)

enum APIKeyStore {
    private static let key = "receiptly_anthropic_key"

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var hasKey: Bool { !apiKey.isEmpty }
}

// MARK: - Analyzer

actor ReceiptAnalyzer {

    static let shared = ReceiptAnalyzer()

    /// Analyze 1+ staged images.  Returns parsed [ReceiptGroup] or throws AnalyzerError.
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

        // Build request
        let imageBlocks: [[String: Any]] = images.map { img in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": img.mediaType,
                    "data": img.b64,
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

        // Execute with timeout
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
            throw AnalyzerError.parseError("No HTTP response")
        }
        guard http.statusCode == 200 else {
            throw AnalyzerError.httpError(http.statusCode, "HTTP \(http.statusCode)")
        }

        // Stream SSE lines
        var accumulated = ""
        var sseBuffer = ""

        for try await line in asyncBytes.lines {
            if Task.isCancelled { throw AnalyzerError.cancelled }

            sseBuffer += line + "\n"

            // Process complete lines
            let lines = sseBuffer.split(separator: "\n", omittingEmptySubsequences: false)
            for rawLine in lines.dropLast() {    // dropLast: possibly incomplete line
                let l = String(rawLine)
                guard l.hasPrefix("data: ") else { continue }
                let payload = String(l.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let evt = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                if let evtType = evt["type"] as? String {
                    if evtType == "content_block_delta",
                       let delta = evt["delta"] as? [String: Any],
                       delta["type"] as? String == "text_delta",
                       let text = delta["text"] as? String {
                        accumulated += text
                    } else if evtType == "error" {
                        let msg = (evt["error"] as? [String: Any])?["message"] as? String ?? "Stream error"
                        throw AnalyzerError.parseError(msg)
                    }
                }
            }
            sseBuffer = lines.last.map(String.init) ?? ""

            // Early exit: try to parse accumulated JSON
            if let result = try? parseGroups(from: accumulated) {
                return result
            }
        }

        // Final parse
        return try parseGroups(from: accumulated)
    }

    // MARK: - JSON parsing

    private func parseGroups(from text: String) throws -> [ReceiptGroup] {
        let json = try extractJSON(from: text)

        // {"not_receipt": true}
        if let obj = json as? [String: Any], obj["not_receipt"] as? Bool == true {
            throw AnalyzerError.notAReceipt
        }

        // Array of groups
        guard let arr = json as? [[String: Any]] else {
            // Single group object
            if let obj = json as? [String: Any] {
                return [try decodeGroup(from: obj)]
            }
            throw AnalyzerError.parseError("Unexpected JSON shape")
        }
        return try arr.map { try decodeGroup(from: $0) }
    }

    private func decodeGroup(from obj: [String: Any]) throws -> ReceiptGroup {
        let data = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(ReceiptGroup.self, from: data)
    }
}

// MARK: - Build Expense from groups (mirrors buildExpense() in receiptAnalyzer.js)

func buildExpense(from groups: [ReceiptGroup]) -> Expense {
    precondition(!groups.isEmpty, "buildExpense: groups must not be empty")

    let normalized: [ExpenseGroup] = groups.map { g in
        let items: [ExpenseItem] = g.items.map { raw in
            ExpenseItem(name: raw.name, quantity: raw.resolvedQty, price: raw.resolvedPrice)
        }
        let computedTotal = items.reduce(0.0) { $0 + $1.price }
        return ExpenseGroup(
            category: validCategory(g.category),
            items: items,
            total: g.total ?? computedTotal
        )
    }

    // Dominant category = highest total
    let dominant = normalized.max(by: { $0.total < $1.total }) ?? normalized[0]
    let first = groups[0]

    return Expense(
        merchant: first.merchant ?? "",
        date: first.date ?? todayString(),
        total: normalized.reduce(0) { $0 + $1.total },
        currency: first.currency ?? "USD",
        category: validCategory(dominant.category),
        items: normalized.flatMap(\.items),
        notes: first.notes ?? "",
        groups: normalized.count > 1 ? normalized : nil
    )
}

// MARK: - Convert Expense back to ReceiptGroup[] (for editing)

func expenseToGroups(_ expense: Expense) -> [ReceiptGroup] {
    if let groups = expense.groups, !groups.isEmpty {
        return groups.map { g in
            ReceiptGroup(
                merchant: expense.merchant,
                date: expense.date,
                currency: expense.currency,
                notes: expense.notes,
                category: g.category,
                items: g.items.map { i in
                    .init(name: i.name, quantity: Double(i.quantity), price: FlexDouble(i.price))
                },
                total: g.total
            )
        }
    }
    return [ReceiptGroup(
        merchant: expense.merchant,
        date: expense.date,
        currency: expense.currency,
        notes: expense.notes,
        category: expense.category,
        items: expense.items.map { i in
            .init(name: i.name, quantity: Double(i.quantity), price: FlexDouble(i.price))
        },
        total: expense.total
    )]
}
