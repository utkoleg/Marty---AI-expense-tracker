import PhotosUI
import SwiftUI
import UIKit

private enum AuthScreen: Equatable {
    case welcome
    case signIn
    case signUpCredentials
    case signUpPreferences
    case signUpProfile
}

private enum AuthField: Hashable {
    case email
    case password
    case confirmPassword
    case fullName
}

struct AuthView: View {
    @ObservedObject var authStore: AuthStore

    @AppStorage(AppPreferences.darkModeEnabledKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @AppStorage(AppPreferences.baseCurrencyKey) private var baseCurrencyRawValue = BaseCurrencyOption.usd.rawValue
    @State private var screen: AuthScreen = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var selectedProfileImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSignInPasswordVisible = false
    @State private var isSignUpPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var hasAttemptedSignIn = false
    @State private var hasAttemptedCredentials = false
    @State private var hasAttemptedProfile = false
    @FocusState private var focusedField: AuthField?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var trimmedName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    private var selectedBaseCurrency: BaseCurrencyOption {
        BaseCurrencyOption(rawValue: baseCurrencyRawValue) ?? .usd
    }

    private var sharedCredentialsValidationMessage: String? {
        if normalizedEmail.isEmpty {
            return loc("Enter your email.", "Введи email.")
        }

        if !normalizedEmail.contains("@") {
            return loc("Enter a valid email address.", "Введи корректный email.")
        }

        if password.count < 6 {
            return loc(
                "Password must be at least 6 characters.",
                "Пароль должен содержать минимум 6 символов."
            )
        }

        return nil
    }

    private var signInValidationMessage: String? {
        guard hasAttemptedSignIn else { return nil }
        return sharedCredentialsValidationMessage
    }

    private var signUpCredentialsValidationMessage: String? {
        guard hasAttemptedCredentials else { return nil }

        if let sharedCredentialsValidationMessage {
            return sharedCredentialsValidationMessage
        }

        if confirmPassword.isEmpty {
            return loc("Repeat your password.", "Повтори пароль.")
        }

        if password != confirmPassword {
            return loc("Passwords do not match.", "Пароли не совпадают.")
        }

        return nil
    }

    private var signUpProfileValidationMessage: String? {
        guard hasAttemptedProfile else { return nil }

        if trimmedName.count < 2 {
            return loc(
                "Enter the name you want to use in your profile.",
                "Введи имя, которое будет использоваться в профиле."
            )
        }

        return nil
    }

    private var canSubmitAuthRequest: Bool {
        authStore.isConfigured && !authStore.isWorking
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppBackgroundView()

                content(for: proxy.size)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: screen)
        .onChange(of: email) { _ in
            hasAttemptedSignIn = false
            hasAttemptedCredentials = false
            authStore.clearFeedback()
        }
        .onChange(of: password) { _ in
            hasAttemptedSignIn = false
            hasAttemptedCredentials = false
            authStore.clearFeedback()
        }
        .onChange(of: confirmPassword) { _ in
            hasAttemptedCredentials = false
            authStore.clearFeedback()
        }
        .onChange(of: fullName) { _ in
            hasAttemptedProfile = false
            authStore.clearFeedback()
        }
        .onChange(of: selectedPhotoItem) { item in
            loadSelectedPhoto(from: item)
        }
    }

    @ViewBuilder
    private func content(for size: CGSize) -> some View {
        switch screen {
        case .welcome:
            welcomeScreen(size: size)
        case .signIn:
            formScroll {
                signInScreen
            }
        case .signUpCredentials:
            formScroll {
                signUpCredentialsScreen
            }
        case .signUpPreferences:
            formScroll {
                signUpPreferencesScreen
            }
        case .signUpProfile:
            formScroll {
                signUpProfileScreen
            }
        }
    }

    private func welcomeScreen(size: CGSize) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                brandLockup

                Spacer(minLength: 18)

                VStack(alignment: .leading, spacing: 16) {
                    Text(loc("Welcome to Marty", "Добро пожаловать в Marty"))
                        .font(.system(size: 46, weight: .regular, design: .serif))
                        .foregroundStyle(AppColor.text)

                    Text(loc(
                        "Capture receipts, keep spending tidy, and grow into cloud sync with a proper account from day one.",
                        "Сканируй чеки, держи расходы в порядке и сразу строй аккаунт так, чтобы потом спокойно перейти к облачной синхронизации."
                    ))
                    .font(.title3)
                    .foregroundStyle(AppColor.muted)
                }

                if let configurationError = authStore.configurationError {
                    FeedbackBanner(
                        text: configurationError,
                        systemName: "exclamationmark.triangle.fill",
                        tint: AppColor.warning
                    )
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    AuthPrimaryButton(
                        title: loc("Get Started", "Get started"),
                        systemName: "arrow.right.circle.fill",
                        isLoading: false,
                        isDisabled: false,
                        action: {
                            Haptics.light()
                            navigate(to: .signUpCredentials)
                        }
                    )

                    AuthSecondaryButton(
                        title: loc("Sign In", "Войти"),
                        systemName: "person.crop.circle",
                        action: {
                            Haptics.light()
                            navigate(to: .signIn)
                        }
                    )
                }
            }
            .frame(minHeight: size.height - 22, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var brandLockup: some View {
        HStack(spacing: 14) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColor.border.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: AppColor.shadowSoft, radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Marty")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColor.text)

                Text(loc("Private receipt tracking", "Приватный учёт чеков"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
            }
        }
    }

    private func formScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                content()
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
    }

    private var signInScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            AuthHeaderBar {
                navigate(to: .welcome)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Welcome back", "С возвращением"))
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(AppColor.text)

                Text(loc(
                    "Sign in to keep your receipts, preferences, and future cloud data under one account.",
                    "Войди в аккаунт, чтобы держать чеки, настройки и будущую облачную синхронизацию в одном месте."
                ))
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
            }

            authFieldsCard(
                title: loc("Email", "Email"),
                passwordTitle: loc("Password", "Пароль"),
                passwordPlaceholder: loc("Enter your password", "Введи пароль"),
                passwordContentType: .password,
                passwordSubmitLabel: .go,
                password: $password,
                isPasswordVisible: $isSignInPasswordVisible,
                confirmPassword: nil,
                isConfirmPasswordVisible: nil,
                passwordAction: submitSignIn
            )

            feedbackStack(validationMessage: signInValidationMessage)

            AuthPrimaryButton(
                title: loc("Sign In", "Войти"),
                systemName: "arrow.right.circle.fill",
                isLoading: authStore.isWorking,
                isDisabled: !canSubmitAuthRequest,
                action: submitSignIn
            )

            Button(loc("Need an account? Get started", "Нет аккаунта? Начать")) {
                Haptics.light()
                navigate(to: .signUpCredentials)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var signUpCredentialsScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            AuthHeaderBar(
                progress: 1.0 / 3.0,
                stepLabel: loc("Step 1 of 3", "Шаг 1 из 3")
            ) {
                navigate(to: .welcome)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Create your account", "Создай аккаунт"))
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(AppColor.text)

                Text(loc(
                    "Start with the essentials. We'll ask for your profile details on the next screen.",
                    "Начни с базовых данных. На следующем экране добавим детали профиля."
                ))
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
            }

            authFieldsCard(
                title: loc("Email", "Email"),
                passwordTitle: loc("Password", "Пароль"),
                passwordPlaceholder: loc("Create a password", "Придумай пароль"),
                passwordContentType: .newPassword,
                passwordSubmitLabel: .continue,
                password: $password,
                isPasswordVisible: $isSignUpPasswordVisible,
                confirmPassword: $confirmPassword,
                isConfirmPasswordVisible: $isConfirmPasswordVisible,
                passwordAction: continueToPreferences
            )

            feedbackStack(validationMessage: signUpCredentialsValidationMessage)

            AuthPrimaryButton(
                title: loc("Continue", "Продолжить"),
                systemName: "arrow.right",
                isLoading: false,
                isDisabled: false,
                action: continueToPreferences
            )

            Button(loc("Already have an account? Sign in", "Уже есть аккаунт? Войти")) {
                Haptics.light()
                navigate(to: .signIn)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var signUpPreferencesScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            AuthHeaderBar(
                progress: 2.0 / 3.0,
                stepLabel: loc("Step 2 of 3", "Шаг 2 из 3")
            ) {
                navigate(to: .signUpCredentials)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Set your defaults", "Выбери базовые настройки"))
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(AppColor.text)

                Text(loc(
                    "Pick the language, base currency, and theme you want Marty to use from the start. You can change all three later in Settings.",
                    "Выбери язык, базовую валюту и тему, с которыми Marty будет работать с самого начала. Позже все три настройки можно изменить в Settings."
                ))
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    preferenceMenuField(
                        title: loc("Language", "Язык"),
                        value: selectedAppLanguage.displayName
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                appLanguageRawValue = language.rawValue
                            } label: {
                                if language.rawValue == appLanguageRawValue {
                                    Label(language.displayName, systemImage: "checkmark")
                                } else {
                                    Text(language.displayName)
                                }
                            }
                        }
                    }

                    preferenceMenuField(
                        title: loc("Currency", "Валюта"),
                        value: selectedBaseCurrency.rawValue
                    ) {
                        ForEach(BaseCurrencyOption.allCases) { currency in
                            Button {
                                baseCurrencyRawValue = currency.rawValue
                            } label: {
                                if currency.rawValue == baseCurrencyRawValue {
                                    Label(currency.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(currency.rawValue)
                                }
                            }
                        }
                    }
                }

                onboardingThemeButton

                Text(loc(
                    "Charts, totals, converted receipts, and the app look will use your selected language, currency, and theme right after sign up.",
                    "Сразу после регистрации графики, сводка, пересчитанные чеки и внешний вид приложения будут использовать выбранные язык, валюту и тему."
                ))
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .cardStyle(fill: AppColor.elevated, stroke: AppColor.border)
            .frame(maxWidth: .infinity)

            AuthPrimaryButton(
                title: loc("Continue", "Продолжить"),
                systemName: "arrow.right",
                isLoading: false,
                isDisabled: false,
                action: continueToProfileDetails
            )
        }
    }

    private var signUpProfileScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            AuthHeaderBar(
                progress: 1,
                stepLabel: loc("Step 3 of 3", "Шаг 3 из 3")
            ) {
                navigate(to: .signUpPreferences)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Let's add some details", "Добавим детали"))
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(AppColor.text)

                Text(loc(
                    "Choose a photo if you want and set the name that should appear in your profile.",
                    "При желании выбери фото и укажи имя, которое будет видно в профиле."
                ))
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
            }

            VStack(alignment: .leading, spacing: 18) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 14) {
                        profileImagePreview

                        Text(
                            selectedProfileImage == nil
                                ? loc("Add profile picture", "Добавить фото профиля")
                                : loc("Change profile picture", "Изменить фото профиля")
                        )
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppColor.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("Your name", "Твоё имя"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.muted)

                    TextField(loc("Your name", "Твоё имя"), text: $fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.join)
                        .focused($focusedField, equals: .fullName)
                        .onSubmit(createAccount)
                        .authInputStyle()
                }

                Text(loc(
                    "The profile photo is stored locally for now and can be synced to Supabase Storage later.",
                    "Фото профиля пока хранится локально на устройстве, а потом его можно будет перенести в Supabase Storage."
                ))
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
            }
            .padding(22)
            .cardStyle(fill: AppColor.elevated, stroke: AppColor.border)

            feedbackStack(validationMessage: signUpProfileValidationMessage)

            AuthPrimaryButton(
                title: loc("Create Account", "Создать аккаунт"),
                systemName: "person.crop.circle.badge.plus",
                isLoading: authStore.isWorking,
                isDisabled: !canSubmitAuthRequest,
                action: createAccount
            )
        }
    }

    private var profileImagePreview: some View {
        Group {
            if let selectedProfileImage {
                Image(uiImage: selectedProfileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .foregroundStyle(AppColor.muted.opacity(0.78))
                    .background(AppColor.tertiarySurface)
            }
        }
        .frame(width: 170, height: 170)
        .background(AppColor.tertiarySurface)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColor.border, lineWidth: 1.5)
        )
        .shadow(color: AppColor.shadowSoft, radius: 18, x: 0, y: 10)
    }

    private func authFieldsCard(
        title: String,
        passwordTitle: String,
        passwordPlaceholder: String,
        passwordContentType: UITextContentType,
        passwordSubmitLabel: SubmitLabel,
        password: Binding<String>,
        isPasswordVisible: Binding<Bool>,
        confirmPassword: Binding<String>?,
        isConfirmPasswordVisible: Binding<Bool>?,
        passwordAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)

                TextField("name@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }
                    .authInputStyle()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(passwordTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)

                authPasswordField(
                    placeholder: passwordPlaceholder,
                    text: password,
                    isVisible: isPasswordVisible,
                    contentType: passwordContentType,
                    submitLabel: confirmPassword == nil ? passwordSubmitLabel : .next,
                    field: .password,
                    onSubmit: {
                        if confirmPassword != nil {
                            focusedField = .confirmPassword
                        } else {
                            passwordAction()
                        }
                    }
                )
            }

            if let confirmPassword, let isConfirmPasswordVisible {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("Confirm password", "Повтори пароль"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.muted)

                    authPasswordField(
                        placeholder: loc("Repeat your password", "Повтори пароль"),
                        text: confirmPassword,
                        isVisible: isConfirmPasswordVisible,
                        contentType: .newPassword,
                        submitLabel: passwordSubmitLabel,
                        field: .confirmPassword,
                        onSubmit: passwordAction
                    )
                }
            }
        }
        .padding(22)
        .cardStyle(fill: AppColor.elevated, stroke: AppColor.border)
    }

    @ViewBuilder
    private func feedbackStack(validationMessage: String?) -> some View {
        if let configurationError = authStore.configurationError {
            FeedbackBanner(
                text: configurationError,
                systemName: "exclamationmark.triangle.fill",
                tint: AppColor.warning
            )
        }

        if let validationMessage {
            FeedbackBanner(
                text: validationMessage,
                systemName: "exclamationmark.circle.fill",
                tint: AppColor.warning
            )
        }

        if let infoMessage = authStore.infoMessage {
            FeedbackBanner(
                text: infoMessage,
                systemName: "envelope.badge.fill",
                tint: AppColor.accent
            )
        }

        if let errorMessage = authStore.errorMessage {
            FeedbackBanner(
                text: errorMessage,
                systemName: "xmark.octagon.fill",
                tint: AppColor.danger
            )
        }
    }

    private func navigate(to destination: AuthScreen, preserveFeedback: Bool = false) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        focusedField = nil
        hasAttemptedSignIn = false
        hasAttemptedCredentials = false
        hasAttemptedProfile = false

        if !preserveFeedback {
            authStore.clearFeedback()
        }

        screen = destination
    }

    private func continueToPreferences() {
        hasAttemptedCredentials = true
        authStore.clearFeedback()

        guard signUpCredentialsValidationMessage == nil else {
            return
        }

        Haptics.light()
        navigate(to: .signUpPreferences)
    }

    private func continueToProfileDetails() {
        Haptics.light()
        navigate(to: .signUpProfile)
    }

    private func submitSignIn() {
        hasAttemptedSignIn = true
        authStore.clearFeedback()

        guard signInValidationMessage == nil else {
            return
        }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            await authStore.signIn(email: normalizedEmail, password: password)
        }
    }

    private func createAccount() {
        hasAttemptedProfile = true
        authStore.clearFeedback()

        guard signUpProfileValidationMessage == nil else {
            return
        }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            await authStore.signUp(
                email: normalizedEmail,
                password: password,
                fullName: trimmedName,
                profileImage: selectedProfileImage
            )

            if authStore.session == nil, authStore.errorMessage == nil {
                navigate(to: .signIn, preserveFeedback: true)
            }
        }
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            await MainActor.run {
                selectedProfileImage = image
            }
        }
    }
}

extension AuthView {
    private var onboardingThemeButton: some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                darkModeEnabled.toggle()
            }
        } label: {
            ThemeSelectionCard(isDarkMode: darkModeEnabled)
        }
        .buttonStyle(.plain)
    }

    private func authPasswordField(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        contentType: UITextContentType,
        submitLabel: SubmitLabel,
        field: AuthField,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .focused($focusedField, equals: field)
            .onSubmit(onSubmit)

            Button {
                Haptics.light()
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .authInputStyle()
    }

    private func preferenceMenuField<MenuContent: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> MenuContent
    ) -> some View {
        Menu {
            content()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            AppColor.bg
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColor.accent)

                Text(loc("Restoring session…", "Восстанавливаем сессию…"))
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
            }
            .padding(28)
            .cardStyle()
            .padding(.horizontal, 24)
        }
    }
}

private struct AuthHeaderBar: View {
    var progress: Double? = nil
    var stepLabel: String? = nil
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: {
                Haptics.light()
                onBack()
            }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppColor.text)
                    .frame(width: 44, height: 44)
                    .background(AppColor.elevated, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                            .stroke(AppColor.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if let progress {
                VStack(alignment: .leading, spacing: 6) {
                    if let stepLabel {
                        Text(stepLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.muted)
                    }

                    SignUpProgressView(progress: progress)
                }
            } else {
                Spacer()
            }
        }
    }
}

private struct SignUpProgressView: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * progress, 24)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.border.opacity(0.5))

                Capsule()
                    .fill(AppGradient.primary)
                    .frame(width: width)
            }
        }
        .frame(height: 7)
    }
}

private struct AuthPrimaryButton: View {
    let title: String
    let systemName: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(AppColor.onAccent)
                } else {
                    Image(systemName: systemName)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
            .background(AppGradient.primary, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .stroke(AppColor.accent2.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColor.onAccent)
        .frame(maxWidth: .infinity)
        .opacity(isDisabled ? 0.55 : 1)
        .disabled(isDisabled)
    }
}

private struct AuthSecondaryButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.headline)

                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
            .background(AppColor.elevated, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .stroke(AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColor.text)
        .frame(maxWidth: .infinity)
    }
}

private struct FeedbackBanner: View {
    let text: String
    let systemName: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.top, 2)

            Text(text)
                .font(.footnote)
                .foregroundStyle(AppColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

private extension View {
    func authInputStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .stroke(AppColor.border, lineWidth: 1)
            )
    }
}
