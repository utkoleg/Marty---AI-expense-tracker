import SwiftUI

private enum RootScreen: Equatable {
    case loading
    case auth
    case app
}

@main
struct ReceiptlyApp: App {
    @AppStorage(AppPreferences.darkModeEnabledKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @StateObject private var authStore: AuthStore

    init() {
        _authStore = StateObject(wrappedValue: AuthStore())
    }

    var body: some Scene {
        let appLanguage = AppLanguage(rawValue: appLanguageRawValue) ?? .english

        WindowGroup {
            rootView
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                .environment(\.locale, appLanguage.locale)
        }
    }

    private var rootView: some View {
        ZStack {
            if currentScreen == .loading {
                AuthLoadingView()
                    .transition(loadingTransition)
            }

            if currentScreen == .app {
                ContentView(dependencies: liveDependencies, authStore: authStore)
                    .transition(appTransition)
            }

            if currentScreen == .auth {
                AuthView(authStore: authStore)
                    .transition(authTransition)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: currentScreen)
    }

    private var currentScreen: RootScreen {
        if authStore.isInitializing {
            return .loading
        }

        return authStore.session != nil ? .app : .auth
    }

    private var liveDependencies: AppDependencies {
        AppDependencies.live(authenticatedUserID: currentUserID)
    }

    private var currentUserID: String? {
        authStore.session?.user.id.uuidString ?? authStore.user?.id.uuidString
    }

    private var loadingTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }

    private var authTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.02, anchor: .leading)),
            removal: .move(edge: .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .leading))
        )
    }

    private var appTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.02, anchor: .trailing)),
            removal: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .trailing))
        )
    }
}
