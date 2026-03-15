import SwiftUI

@main
struct ReceiptlyApp: App {
    @AppStorage(AppPreferences.darkModeEnabledKey) private var darkModeEnabled = false
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    private let dependencies: AppDependencies

    init() {
        dependencies = .live()
    }

    var body: some Scene {
        let appLanguage = AppLanguage(rawValue: appLanguageRawValue) ?? .english

        WindowGroup {
            ContentView(dependencies: dependencies)
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                .environment(\.locale, appLanguage.locale)
        }
    }
}
