import Foundation
import Supabase
import UIKit

enum AnalyzerError: LocalizedError, Equatable {
    case serviceNotConfigured
    case notAReceipt
    case httpError(Int, String)
    case timeout
    case cancelled
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .serviceNotConfigured:
            return loc(
                "Receipt scanning is not configured. Deploy the analyze-receipt Edge Function and add ANTHROPIC_API_KEY to Supabase secrets.",
                "Сканирование чеков не настроено. Задеплой функцию analyze-receipt и добавь ANTHROPIC_API_KEY в secrets Supabase."
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

actor SupabaseReceiptAnalyzer: ReceiptAnalyzing {
    private let supabase: SupabaseClient?

    init(supabase: SupabaseClient? = SupabaseService.shared) {
        self.supabase = supabase
    }

    func analyze(images: [StagedImage], timeoutSeconds: Double = 60) async throws -> [ReceiptGroup] {
        guard let supabase else {
            throw AnalyzerError.serviceNotConfigured
        }

        do {
            let payload = AnalyzeReceiptFunctionRequest(
                images: images.map { AnalyzeReceiptFunctionRequest.Image(stagedImage: $0) },
                timeoutSeconds: timeoutSeconds
            )

            return try await supabase.functions.invoke(
                "analyze-receipt",
                options: FunctionInvokeOptions(body: payload),
                decode: { data, _ in
                    try decodeReceiptGroupsResponse(from: data)
                }
            )
        } catch let error as AnalyzerError {
            throw error
        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch is CancellationError {
            throw AnalyzerError.cancelled
        } catch {
            throw AnalyzerError.parseError(error.localizedDescription)
        }
    }
}

func decodeReceiptGroupsResponse(from data: Data) throws -> [ReceiptGroup] {
    let json = try JSONSerialization.jsonObject(with: data)

    if let obj = json as? [String: Any], obj[ReceiptGroup.notReceiptKey] as? Bool == true {
        throw AnalyzerError.notAReceipt
    }

    guard let array = json as? [[String: Any]] else {
        if let obj = json as? [String: Any] {
            return [try decodeReceiptGroup(from: obj)]
        }

        throw AnalyzerError.parseError(loc("Unexpected JSON shape", "Неожиданная структура JSON"))
    }

    return try array.map { try decodeReceiptGroup(from: $0) }
}

func decodeFunctionErrorMessage(from data: Data) -> String? {
    guard
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return nil
    }

    if let error = json["error"] as? String, !error.isEmpty {
        return error
    }

    if let message = json["message"] as? String, !message.isEmpty {
        return message
    }

    return nil
}

private func decodeReceiptGroup(from obj: [String: Any]) throws -> ReceiptGroup {
    let data = try JSONSerialization.data(withJSONObject: obj)
    return try JSONDecoder().decode(ReceiptGroup.self, from: data)
}

private func mapFunctionsError(_ error: FunctionsError) -> AnalyzerError {
    switch error {
    case .relayError:
        return .parseError(loc(
            "Could not reach the receipt analysis function.",
            "Не удалось обратиться к функции анализа чеков."
        ))
    case .httpError(let statusCode, let data):
        if statusCode == 504 {
            return .timeout
        }

        if statusCode == 401 {
            return .httpError(statusCode, functionAuthorizationMessage(for: decodeFunctionErrorMessage(from: data)))
        }

        let message = decodeFunctionErrorMessage(from: data) ?? "HTTP \(statusCode)"
        return .httpError(statusCode, message)
    }
}

func functionAuthorizationMessage(for rawMessage: String?) -> String {
    let normalized = rawMessage?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""

    if normalized.contains("invalid user token") || normalized.contains("jwt expired") {
        return loc(
            "Your session expired. Sign in again and try scanning the receipt one more time.",
            "Сессия истекла. Войди в аккаунт заново и попробуй еще раз отсканировать чек."
        )
    }

    if normalized.contains("invalid jwt") || normalized.isEmpty {
        return loc(
            "Receipt scanning is using an outdated function deployment. Redeploy analyze-receipt with verify_jwt disabled, then try again.",
            "Для сканирования чеков используется устаревший деплой функции. Задеплой analyze-receipt с выключенной verify_jwt, потом попробуй снова."
        )
    }

    return rawMessage ?? loc(
        "The receipt analysis function rejected authorization.",
        "Функция анализа чеков отклонила авторизацию."
    )
}

private struct AnalyzeReceiptFunctionRequest: Encodable {
    struct Image: Encodable {
        let b64: String
        let mediaType: String

        init(stagedImage: StagedImage) {
            b64 = stagedImage.b64
            mediaType = stagedImage.mediaType
        }
        enum CodingKeys: String, CodingKey {
            case b64
            case mediaType = "media_type"
        }
    }

    let images: [Image]
    let timeoutSeconds: Double
}
