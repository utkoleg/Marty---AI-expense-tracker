import Foundation
import Supabase

struct SupabaseConfiguration: Equatable {
    static let urlKey = "SUPABASE_URL"
    static let publishableKeyKey = "SUPABASE_PUBLISHABLE_KEY"
    static let urlPlaceholder = "https://YOUR-PROJECT-REF.supabase.co"
    static let publishableKeyPlaceholder = "YOUR_SUPABASE_PUBLISHABLE_KEY"

    let url: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> SupabaseConfiguration {
        try load(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func load(infoDictionary: [String: Any]) throws -> SupabaseConfiguration {
        guard let rawURL = infoDictionary[urlKey] as? String else {
            throw SupabaseConfigurationError.missingValue(urlKey)
        }

        let trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, trimmedURL != urlPlaceholder else {
            throw SupabaseConfigurationError.missingValue(urlKey)
        }

        guard
            let url = URL(string: trimmedURL),
            let scheme = url.scheme?.lowercased(),
            scheme == "https",
            url.host?.isEmpty == false
        else {
            throw SupabaseConfigurationError.invalidURL(trimmedURL)
        }

        guard let rawKey = infoDictionary[publishableKeyKey] as? String else {
            throw SupabaseConfigurationError.missingValue(publishableKeyKey)
        }

        let trimmedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, trimmedKey != publishableKeyPlaceholder else {
            throw SupabaseConfigurationError.missingValue(publishableKeyKey)
        }

        return SupabaseConfiguration(url: url, publishableKey: trimmedKey)
    }
}

enum SupabaseConfigurationError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return loc(
                "Set \(key) in your build settings before using Supabase auth.",
                "Укажи \(key) в build settings перед использованием Supabase auth."
            )
        case .invalidURL(let value):
            return loc(
                "Supabase URL is invalid: \(value)",
                "Указан некорректный Supabase URL: \(value)"
            )
        }
    }
}

enum SupabaseService {
    private static let configurationResult = Result { try SupabaseConfiguration.load() }

    private static var configuration: SupabaseConfiguration? {
        guard case .success(let configuration) = configurationResult else {
            return nil
        }

        return configuration
    }

    static let shared: SupabaseClient? = {
        guard let configuration else {
            return nil
        }

        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()

    static func makeAuthProbeClient() -> SupabaseClient? {
        guard let configuration else {
            return nil
        }

        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryAuthLocalStorage(),
                    storageKey: "signup-probe",
                    emitLocalSessionAsInitialSession: false
                )
            )
        )
    }

    static var configurationError: String? {
        guard case .failure(let error) = configurationResult else {
            return nil
        }

        return error.localizedDescription
    }
}

private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}
