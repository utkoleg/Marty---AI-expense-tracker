import XCTest
import Supabase
@testable import ReceiptlyNative

final class AuthSignUpInterpretationTests: XCTestCase {
    func testInterpretSignUpResponseTreatsUserOnlyResponseAsPendingConfirmation() {
        let response = AuthResponse.user(
            makeUser(
                fullName: "Marty",
                identities: nil
            )
        )

        XCTAssertEqual(
            interpretSignUpResponse(response),
            .needsEmailConfirmation
        )
    }

    func testInterpretSignUpResponseKeepsRealNewUserAsConfirmationFlow() {
        let response = AuthResponse.user(
            makeUser(
                fullName: "Marty",
                identities: [makeEmailIdentity()]
            )
        )

        XCTAssertEqual(
            interpretSignUpResponse(response),
            .needsEmailConfirmation
        )
    }

    func testInterpretSignUpProbeErrorMarksInvalidCredentialsAsExistingAccount() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "Invalid login credentials",
            errorCode: .invalidCredentials,
            underlyingData: Data(),
            underlyingResponse: response
        )

        XCTAssertEqual(
            interpretSignUpProbeError(error),
            .emailAlreadyRegistered
        )
    }

    func testInterpretSignUpProbeErrorKeepsEmailNotConfirmedAsConfirmationFlow() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "Email not confirmed",
            errorCode: .emailNotConfirmed,
            underlyingData: Data(),
            underlyingResponse: response
        )

        XCTAssertEqual(
            interpretSignUpProbeError(error),
            .needsEmailConfirmation
        )
    }

    func testUserFacingAuthErrorMessageMapsDuplicateEmailErrors() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 422,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "User already registered",
            errorCode: .emailExists,
            underlyingData: Data(),
            underlyingResponse: response
        )

        XCTAssertEqual(
            userFacingAuthErrorMessage(error),
            duplicateEmailAuthMessage()
        )
    }

    private func makeUser(
        fullName: String?,
        identities: [UserIdentity]?
    ) -> User {
        let id = UUID()
        var metadata: [String: AnyJSON] = [:]
        if let fullName {
            metadata["full_name"] = .string(fullName)
        }

        return User(
            id: id,
            appMetadata: [:],
            userMetadata: metadata,
            aud: "authenticated",
            confirmationSentAt: Date(),
            email: "test@example.com",
            createdAt: Date(),
            updatedAt: Date(),
            identities: identities
        )
    }

    private func makeEmailIdentity() -> UserIdentity {
        let id = UUID()
        return UserIdentity(
            id: id.uuidString,
            identityId: id,
            userId: id,
            identityData: ["sub": .string(id.uuidString)],
            provider: "email",
            createdAt: Date(),
            lastSignInAt: Date(),
            updatedAt: Date()
        )
    }
}
