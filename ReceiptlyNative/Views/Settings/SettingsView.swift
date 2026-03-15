import SwiftUI
import UIKit

struct SettingsView: View {
    var authStore: AuthStore? = nil
    let expenses: [Expense]
    let stats: Stats
    var onClearAll: () -> Void

    @AppStorage(AppPreferences.darkModeEnabledKey) private var darkModeEnabled = false
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @AppStorage(AppPreferences.baseCurrencyKey) private var baseCurrencyRawValue = BaseCurrencyOption.usd.rawValue
    @State private var showClearConfirm = false
    @State private var apiKey = APIKeyStore.apiKey
    @State private var showKeySaved = false
    @State private var exportURL: URL? = nil
    @State private var showShare = false

    private var totalItems: Int {
        expenses.reduce(0) { $0 + $1.items.count }
    }

    private var avgPerReceipt: String {
        expenses.isEmpty ? "—" : fmt(stats.totalSpent / Double(expenses.count), currencyCode: stats.displayCurrency)
    }

    var body: some View {
        Form {
            Section(loc("Summary", "Сводка")) {
                LabeledContent(loc("Receipts", "Чеки"), value: "\(expenses.count)")
                LabeledContent(loc("Items", "Позиции"), value: "\(totalItems)")
                LabeledContent(loc("Total Spent", "Всего потрачено"), value: fmt(stats.totalSpent, currencyCode: stats.displayCurrency))
                LabeledContent(loc("Categories", "Категории"), value: "\(stats.usedCats.count)")
                LabeledContent(loc("Average per Receipt", "Среднее за чек"), value: avgPerReceipt)
                LabeledContent(loc("Base Currency", "Базовая валюта"), value: normalizedCurrencyCode(baseCurrencyRawValue))
            }

            if let authStore {
                Section {
                    HStack(spacing: 14) {
                        AccountAvatarView(image: authStore.profileImage)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(authStore.displayName ?? loc("Profile", "Профиль"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColor.text)

                            Text(authStore.user?.email ?? loc("Unknown", "Неизвестно"))
                                .font(.footnote)
                                .foregroundStyle(AppColor.muted)
                        }
                    }

                    if let displayName = authStore.displayName {
                        LabeledContent(loc("Name", "Имя"), value: displayName)
                    }

                    Button(role: .destructive) {
                        Task {
                            await authStore.signOut()
                        }
                    } label: {
                        Label(loc("Sign Out", "Выйти"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(authStore.isWorking)
                } header: {
                    Text(loc("Account", "Аккаунт"))
                } footer: {
                    if let errorMessage = authStore.errorMessage {
                        Text(errorMessage)
                    } else {
                        Text(loc(
                            "Email/password auth is handled by Supabase. Social login and magic links can be added later.",
                            "Вход по email и паролю сейчас работает через Supabase. Социальный вход и magic link можно добавить позже."
                        ))
                    }
                }
            }

            Section {
                Toggle(isOn: darkModeBinding) {
                    Label {
                        Text(loc("Dark Mode", "Темная тема"))
                    } icon: {
                        AppearanceModeIcon(isDarkMode: darkModeEnabled)
                    }
                }
            } header: {
                Text(loc("Appearance", "Оформление"))
            } footer: {
                Text(loc(
                    "Switches the whole app to Apple-style dark surfaces, dynamic text contrast, and native grouped backgrounds.",
                    "Переключает все приложение на темную тему в стиле iOS с адаптивным контрастом и системными фонами."
                ))
            }

            Section {
                Picker(loc("Language", "Язык"), selection: $appLanguageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            } header: {
                Text(loc("Language", "Язык"))
            } footer: {
                Text(loc(
                    "Changes the app language immediately.",
                    "Меняет язык приложения сразу."
                ))
            }

            Section {
                Picker(loc("Base Currency", "Базовая валюта"), selection: $baseCurrencyRawValue) {
                    ForEach(BaseCurrencyOption.allCases) { currency in
                        Text(currency.displayName).tag(currency.rawValue)
                    }
                }
            } header: {
                Text(loc("Currency", "Валюта"))
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc(
                        "Charts and totals use the base currency. Receipts in other currencies are converted using the latest available rate and still keep the original amount in parentheses.",
                        "Графики и сводка считаются в базовой валюте. Если чек в другой валюте, приложение пересчитает его по актуальному курсу и покажет исходную сумму в скобках."
                    ))

                    Link(
                        loc("Rates by ExchangeRate-API", "Курсы: ExchangeRate-API"),
                        destination: URL(string: "https://www.exchangerate-api.com")!
                    )
                }
            }

            Section {
                Button {
                    exportCSV()
                } label: {
                    Label(loc("Export CSV", "Экспорт CSV"), systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(loc("Clear All Expenses", "Удалить все расходы"), systemImage: "trash")
                }
                .disabled(expenses.isEmpty)
            } header: {
                Text(loc("Data", "Данные"))
            } footer: {
                Text(loc(
                    "Exports create a CSV snapshot you can share or import elsewhere.",
                    "Экспорт создает CSV-файл, которым можно поделиться или импортировать в другое приложение."
                ))
            }

            Section {
                SecureField(loc("Anthropic API key", "API-ключ Anthropic"), text: $apiKey)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(showKeySaved ? loc("Saved", "Сохранено") : loc("Save Key", "Сохранить ключ")) {
                    APIKeyStore.apiKey = apiKey
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    showKeySaved = true

                    UIActionScheduler.perform(after: UIActionDelay.transientStateResetSeconds) {
                        showKeySaved = false
                    }
                }
                .tint(showKeySaved ? AppColor.success : AppColor.accent)
            } header: {
                Text(loc("AI Scanning", "AI-сканирование"))
            } footer: {
                Text(loc(
                    "The key is stored locally on this device and used only for receipt analysis.",
                    "Ключ хранится локально на этом устройстве и используется только для анализа чеков."
                ))
            }

            Section(loc("About Marty", "О Marty")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc(
                        "Marty scans receipts with Claude, extracts line items, groups purchases into categories, and keeps your history on-device.",
                        "Marty сканирует чеки с помощью Claude, извлекает позиции, распределяет покупки по категориям и хранит историю на устройстве."
                    ))

                    Text(loc(
                        "The redesigned interface follows native iOS patterns so navigation, actions, and data review feel more predictable.",
                        "Обновленный интерфейс следует нативным паттернам iOS, поэтому навигация, действия и просмотр данных ощущаются более привычно."
                    ))
                        .foregroundStyle(AppColor.muted)
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .confirmationDialog(loc("Clear all expenses?", "Удалить все расходы?"), isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button(loc("Clear All", "Удалить все"), role: .destructive) { onClearAll() }
            Button(loc("Cancel", "Отмена"), role: .cancel) {}
        } message: {
            Text(loc("This cannot be undone.", "Это действие нельзя отменить."))
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
    }

    private func exportCSV() {
        exportURL = try? ExpenseCSVExporter.writeTemporaryCSV(expenses: expenses)
        showShare = true
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { darkModeEnabled },
            set: { enabled in
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    darkModeEnabled = enabled
                }
            }
        )
    }
}

private struct AppearanceModeIcon: View {
    let isDarkMode: Bool

    var body: some View {
        ZStack {
            modeSymbol(
                systemName: "moon.fill",
                tint: AppColor.accent,
                isVisible: !isDarkMode,
                hiddenRotation: 70
            )

            modeSymbol(
                systemName: "sun.max.fill",
                tint: Color(uiColor: .systemYellow),
                isVisible: isDarkMode,
                hiddenRotation: -70
            )
        }
        .frame(width: 22, height: 22)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isDarkMode)
        .accessibilityHidden(true)
    }

    private func modeSymbol(systemName: String, tint: Color, isVisible: Bool, hiddenRotation: Double) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .scaleEffect(isVisible ? 1 : 0.55)
            .rotationEffect(.degrees(isVisible ? 0 : hiddenRotation))
            .opacity(isVisible ? 1 : 0)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct AccountAvatarView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(AppColor.muted.opacity(0.78))
                    .background(AppColor.tertiarySurface)
            }
        }
        .frame(width: 54, height: 54)
        .background(AppColor.tertiarySurface)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}
