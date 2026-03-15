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

    func testDecodeReceiptGroupsResponseAcceptsSingleObject() throws {
        let data = Data("""
        {
          "merchant": "Target",
          "date": "2024-12-11",
          "currency": "USD",
          "notes": "weekly",
          "category": "Groceries",
          "items": [
            { "name": "Milk", "quantity": 1, "price": 3.5 }
          ],
          "total": 3.5
        }
        """.utf8)

        let groups = try decodeReceiptGroupsResponse(from: data)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.merchant, "Target")
        XCTAssertEqual(groups.first?.category, "Groceries")
    }

    func testDecodeReceiptGroupsResponseRejectsNotReceiptPayload() {
        let data = Data(#"{"not_receipt":true}"#.utf8)

        XCTAssertThrowsError(try decodeReceiptGroupsResponse(from: data)) { error in
            XCTAssertEqual(error as? AnalyzerError, .notAReceipt)
        }
    }

    func testDecodeFunctionErrorMessageReadsEdgeFunctionErrorPayload() {
        let data = Data(#"{"error":"Missing ANTHROPIC_API_KEY secret."}"#.utf8)

        XCTAssertEqual(
            decodeFunctionErrorMessage(from: data),
            "Missing ANTHROPIC_API_KEY secret."
        )
    }

    func testDecodeFunctionErrorMessageReadsGatewayMessagePayload() {
        let data = Data(#"{"code":401,"message":"Invalid JWT"}"#.utf8)

        XCTAssertEqual(
            decodeFunctionErrorMessage(from: data),
            "Invalid JWT"
        )
    }

    func testFunctionAuthorizationMessageForGatewayJWTFailureIsActionable() {
        let message = functionAuthorizationMessage(for: "Invalid JWT")

        XCTAssertTrue(message.localizedCaseInsensitiveContains("Redeploy analyze-receipt"))
    }
}
