import Foundation
import Supabase
import UIKit

enum AuthSignUpInterpretation: Equatable {
    case signedIn
    case needsEmailConfirmation
    case emailAlreadyRegistered
}

func duplicateEmailAuthMessage() -> String {
    loc(
        "This email is already registered. Sign in instead.",
        "Эта почта уже зарегистрирована. Войди в аккаунт."
    )
}

func emailConfirmationRequiredMessage() -> String {
    loc(
        "Check your email and confirm this address before signing in.",
        "Проверь почту и подтверди этот email, прежде чем входить."
    )
}

func interpretSignUpResponse(_ response: AuthResponse) -> AuthSignUpInterpretation {
    if response.session != nil {
        return .signedIn
    }

    return .needsEmailConfirmation
}

func interpretSignUpProbeError(_ error: Error) -> AuthSignUpInterpretation {
    guard let authError = error as? AuthError else {
        return .needsEmailConfirmation
    }

    switch authError.errorCode {
    case .invalidCredentials, .emailExists, .userAlreadyExists, .identityAlreadyExists:
        return .emailAlreadyRegistered
    case .emailNotConfirmed:
        return .needsEmailConfirmation
    default:
        return .needsEmailConfirmation
    }
}

func userFacingAuthErrorMessage(_ error: Error) -> String {
    if let authError = error as? AuthError {
        switch authError.errorCode {
        case .emailExists, .userAlreadyExists, .identityAlreadyExists:
            return duplicateEmailAuthMessage()
        default:
            return authError.localizedDescription
        }
    }

    return error.localizedDescription
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var user: User?
    @Published private(set) var profileImage: UIImage?
    @Published private(set) var isInitializing = true
    @Published private(set) var isWorking = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?

    let configurationError: String?

    private let supabase: SupabaseClient?
    private let profileImageStore: UserProfileImageStore
    private var authStateTask: Task<Void, Never>?

    init(
        supabase: SupabaseClient? = SupabaseService.shared,
        configurationError: String? = SupabaseService.configurationError,
        profileImageStore: UserProfileImageStore = .shared
    ) {
        self.supabase = supabase
        self.configurationError = configurationError
        self.profileImageStore = profileImageStore
        observeAuthState()
    }

    var isConfigured: Bool {
        supabase != nil && configurationError == nil
    }

    var displayName: String? {
        let fullName = user?.userMetadata["full_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let fullName, !fullName.isEmpty else {
            return nil
        }

        return fullName
    }

    func signIn(email: String, password: String) async {
        guard let supabase else {
            errorMessage = configurationError
            return
        }

        resetFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await supabase.auth.signIn(email: email, password: password)

            let refreshedSession: Session?
            if let currentSession = supabase.auth.currentSession {
                refreshedSession = currentSession
            } else {
                refreshedSession = try? await supabase.auth.session
            }

            applySession(refreshedSession)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.auth.error("Supabase sign-in failed: \(String(describing: error), privacy: .public)")
        }
    }

    func signUp(email: String, password: String, fullName: String, profileImage selectedProfileImage: UIImage?) async {
        guard let supabase else {
            errorMessage = configurationError
            return
        }

        resetFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )

            let outcome = await finalizeSignUpOutcome(
                response: response,
                email: email,
                password: password
            )

            switch outcome {
            case .emailAlreadyRegistered:
                errorMessage = duplicateEmailAuthMessage()
                return
            case .signedIn, .needsEmailConfirmation:
                break
            }

            if let selectedProfileImage {
                do {
                    try profileImageStore.save(selectedProfileImage, for: response.user.id)
                } catch {
                    AppLogger.auth.error("Profile image save failed: \(String(describing: error), privacy: .public)")
                }
            }

            if let responseSession = response.session {
                applySession(responseSession)
            } else {
                applySession(supabase.auth.currentSession)
                infoMessage = emailConfirmationRequiredMessage()
            }
        } catch {
            errorMessage = userFacingAuthErrorMessage(error)
            AppLogger.auth.error("Supabase sign-up failed: \(String(describing: error), privacy: .public)")
        }
    }

    func signOut() async {
        guard let supabase else {
            errorMessage = configurationError
            return
        }

        resetFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            try await supabase.auth.signOut()
            applySession(nil)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.auth.error("Supabase sign-out failed: \(String(describing: error), privacy: .public)")
        }
    }

    func clearFeedback() {
        resetFeedback()
    }

    private func observeAuthState() {
        guard let supabase else {
            isInitializing = false
            return
        }

        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            guard let self else { return }

            let initialSession: Session?
            if let currentSession = supabase.auth.currentSession {
                initialSession = currentSession
            } else {
                initialSession = try? await supabase.auth.session
            }

            self.applyInitialSession(initialSession)

            for await (_, session) in supabase.auth.authStateChanges {
                self.applyObservedSession(session)
            }
        }
    }

    private func applyInitialSession(_ session: Session?) {
        applySession(session, shouldResetFeedback: false)
        isInitializing = false
    }

    private func applyObservedSession(_ session: Session?) {
        applySession(session, shouldResetFeedback: false)
        isInitializing = false
    }

    private func applySession(_ session: Session?, shouldResetFeedback: Bool = false) {
        let activeSession = normalizedSession(session)

        self.session = activeSession
        user = activeSession?.user
        profileImage = activeSession.flatMap { profileImageStore.image(for: $0.user.id) }

        if shouldResetFeedback {
            resetFeedback()
        }
    }

    private func normalizedSession(_ session: Session?) -> Session? {
        guard let session else {
            return nil
        }

        return session.isExpired ? nil : session
    }

    private func resetFeedback() {
        errorMessage = nil
        infoMessage = nil
    }

    private func finalizeSignUpOutcome(
        response: AuthResponse,
        email: String,
        password: String
    ) async -> AuthSignUpInterpretation {
        let initialOutcome = interpretSignUpResponse(response)

        guard initialOutcome == .needsEmailConfirmation else {
            return initialOutcome
        }

        guard let probeClient = SupabaseService.makeAuthProbeClient() else {
            return .needsEmailConfirmation
        }

        do {
            _ = try await probeClient.auth.signIn(email: email, password: password)
            return .emailAlreadyRegistered
        } catch {
            return interpretSignUpProbeError(error)
        }
    }
}
