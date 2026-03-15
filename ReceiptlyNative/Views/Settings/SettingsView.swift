import SwiftUI
import UIKit

struct SettingsView: View {
    var authStore: AuthStore? = nil
    let expenses: [Expense]
    let stats: Stats
    var isRefreshingCurrency = false
    var currencyRefreshMessage: String? = nil
    var onClearAll: () -> Void

    @AppStorage(AppPreferences.darkModeEnabledKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @AppStorage(AppPreferences.baseCurrencyKey) private var baseCurrencyRawValue = BaseCurrencyOption.usd.rawValue
    @State private var showClearConfirm = false
    @State private var exportURL: URL? = nil
    @State private var showShare = false

    private var totalItems: Int {
        expenses.reduce(0) { $0 + $1.items.count }
    }

    private var avgPerReceipt: String {
        expenses.isEmpty ? "—" : fmt(stats.totalSpent / Double(expenses.count), currencyCode: stats.displayCurrency)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    private var selectedBaseCurrency: BaseCurrencyOption {
        BaseCurrencyOption(rawValue: baseCurrencyRawValue) ?? .usd
    }

    var body: some View {
        Form {
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

                    Button {
                        Task {
                            await authStore.signOut()
                        }
                    } label: {
                        SettingsActionRow(
                            title: loc("Sign Out", "Выйти"),
                            systemName: "rectangle.portrait.and.arrow.right",
                            iconTint: AppColor.danger
                        )
                    }
                    .disabled(authStore.isWorking)
                } header: {
                    Text(loc("Account", "Аккаунт"))
                } footer: {
                    if let errorMessage = authStore.errorMessage {
                        Text(errorMessage)
                    }
                }
            }

            Section {
                NavigationLink {
                    SettingsSummaryView(
                        receiptCount: expenses.count,
                        itemCount: totalItems,
                        totalSpent: stats.totalSpent,
                        displayCurrency: stats.displayCurrency,
                        categoryCount: stats.usedCats.count,
                        averagePerReceipt: avgPerReceipt,
                        baseCurrencyCode: normalizedCurrencyCode(baseCurrencyRawValue)
                    )
                } label: {
                    SettingsNavigationRow(
                        title: loc("Summary", "Сводка"),
                        value: fmt(stats.totalSpent, currencyCode: stats.displayCurrency),
                        systemName: "chart.bar.doc.horizontal"
                    )
                }
            }

            Section {
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        darkModeEnabled.toggle()
                    }
                } label: {
                    ThemeSelectionCard(isDarkMode: darkModeEnabled, compact: true)
                }
                .buttonStyle(.plain)
            } header: {
                Text(loc("Appearance", "Оформление"))
            } footer: {
                Text(loc(
                    "Switches the whole app to Apple-style dark surfaces, dynamic text contrast, and native grouped backgrounds.",
                    "Переключает все приложение на темную тему в стиле iOS с адаптивным контрастом и системными фонами."
                ))
            }

            Section {
                Menu {
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
                } label: {
                    SettingsSelectionRow(
                        title: loc("Language", "Язык"),
                        value: selectedLanguage.displayName
                    )
                }
                .disabled(isRefreshingCurrency)
            } header: {
                Text(loc("Language", "Язык"))
            } footer: {
                Text(loc(
                    "Changes the app language immediately.",
                    "Меняет язык приложения сразу."
                ))
            }

            Section {
                Menu {
                    ForEach(BaseCurrencyOption.allCases) { currency in
                        Button {
                            baseCurrencyRawValue = currency.rawValue
                        } label: {
                            if currency.rawValue == baseCurrencyRawValue {
                                Label(currency.displayName, systemImage: "checkmark")
                            } else {
                                Text(currency.displayName)
                            }
                        }
                    }
                } label: {
                    SettingsSelectionRow(
                        title: loc("Base Currency", "Базовая валюта"),
                        value: selectedBaseCurrency.displayName
                    )
                }
                .disabled(isRefreshingCurrency)
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

                    if isRefreshingCurrency {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)

                            Text(loc(
                                "Recalculating totals in the new base currency.",
                                "Пересчитываем суммы в новой базовой валюте."
                            ))
                        }
                    } else if let currencyRefreshMessage {
                        Text(currencyRefreshMessage)
                            .foregroundStyle(AppColor.danger)
                    }
                }
            }

            Section {
                Button {
                    exportCSV()
                } label: {
                    Label(loc("Export CSV", "Экспорт CSV"), systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)

                Button {
                    showClearConfirm = true
                } label: {
                    SettingsActionRow(
                        title: loc("Clear All Expenses", "Удалить все расходы"),
                        systemName: "trash",
                        iconTint: AppColor.danger
                    )
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

            Section(loc("About Marty", "О Marty")) {
                Text(loc(
                    "Marty is currently in beta.",
                    "Marty сейчас находится в бета-тесте."
                ))
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
}

private struct SettingsSummaryView: View {
    let receiptCount: Int
    let itemCount: Int
    let totalSpent: Double
    let displayCurrency: String
    let categoryCount: Int
    let averagePerReceipt: String
    let baseCurrencyCode: String

    var body: some View {
        Form {
            Section {
                LabeledContent(loc("Receipts", "Чеки"), value: "\(receiptCount)")
                LabeledContent(loc("Items", "Позиции"), value: "\(itemCount)")
                LabeledContent(loc("Total Spent", "Всего потрачено"), value: fmt(totalSpent, currencyCode: displayCurrency))
                LabeledContent(loc("Categories", "Категории"), value: "\(categoryCount)")
                LabeledContent(loc("Average per Receipt", "Среднее за чек"), value: averagePerReceipt)
                LabeledContent(loc("Base Currency", "Базовая валюта"), value: baseCurrencyCode)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(loc("Summary", "Сводка"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsSelectionRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let value: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.accent)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(AppColor.text)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemName: String
    let iconTint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(AppColor.text)

            Spacer()
        }
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
