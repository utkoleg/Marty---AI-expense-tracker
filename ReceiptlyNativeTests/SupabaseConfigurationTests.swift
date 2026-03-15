import XCTest
@testable import ReceiptlyNative

final class SupabaseConfigurationTests: XCTestCase {
    func testLoadAcceptsValidValues() throws {
        let configuration = try SupabaseConfiguration.load(infoDictionary: [
            SupabaseConfiguration.urlKey: "https://demo.supabase.co",
            SupabaseConfiguration.publishableKeyKey: "demo-publishable-key",
        ])

        XCTAssertEqual(configuration.url.absoluteString, "https://demo.supabase.co")
        XCTAssertEqual(configuration.publishableKey, "demo-publishable-key")
    }

    func testLoadRejectsPlaceholderValues() {
        XCTAssertThrowsError(
            try SupabaseConfiguration.load(infoDictionary: [
                SupabaseConfiguration.urlKey: SupabaseConfiguration.urlPlaceholder,
                SupabaseConfiguration.publishableKeyKey: SupabaseConfiguration.publishableKeyPlaceholder,
            ])
        ) { error in
            XCTAssertEqual(
                error as? SupabaseConfigurationError,
                .missingValue(SupabaseConfiguration.urlKey)
            )
        }
    }

    func testLoadRejectsInvalidURL() {
        XCTAssertThrowsError(
            try SupabaseConfiguration.load(infoDictionary: [
                SupabaseConfiguration.urlKey: "not-a-url",
                SupabaseConfiguration.publishableKeyKey: "demo-publishable-key",
            ])
        ) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .invalidURL("not-a-url"))
        }
    }
}
