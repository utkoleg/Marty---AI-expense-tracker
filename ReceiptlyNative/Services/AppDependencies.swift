import Foundation
import Supabase

struct AppDependencies {
    let repository: any ExpenseRepository
    let analyzer: any ReceiptAnalyzing
    let exchangeRates: any ExchangeRateProviding

    static func live(
        authenticatedUserID: String? = nil,
        supabase: SupabaseClient? = SupabaseService.shared
    ) -> AppDependencies {
        let localRepository = LocalExpenseRepository()
        let repository: any ExpenseRepository

        if let authenticatedUserID, let supabase {
            repository = SupabaseExpenseRepository(
                userID: authenticatedUserID,
                remoteStore: SupabaseExpenseRemoteStore(supabase: supabase),
                migrationSourceRepository: localRepository
            )
        } else {
            repository = localRepository
        }

        return AppDependencies(
            repository: repository,
            analyzer: AnthropicReceiptAnalyzer(),
            exchangeRates: ExchangeRateService()
        )
    }

    static func preview() -> AppDependencies {
        AppDependencies(
            repository: InMemoryExpenseRepository(initialExpenses: PreviewExpenseData.expenses),
            analyzer: PreviewReceiptAnalyzer(),
            exchangeRates: PreviewExchangeRateService()
        )
    }
}

private struct PreviewReceiptAnalyzer: ReceiptAnalyzing {
    func analyze(images: [StagedImage], timeoutSeconds: Double) async throws -> [ReceiptGroup] {
        throw AnalyzerError.noAPIKey
    }
}

private struct PreviewExchangeRateService: ExchangeRateProviding {
    func latestRate(from: String, to: String) async throws -> ExchangeRateQuote {
        ExchangeRateQuote(
            from: normalizedCurrencyCode(from),
            to: normalizedCurrencyCode(to),
            rate: normalizedCurrencyCode(from) == "KZT" && normalizedCurrencyCode(to) == "USD" ? 0.002 : 1,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            effectiveAt: nil
        )
    }
}

private enum PreviewExpenseData {
    static let expenses: [Expense] = [
        Expense(
            merchant: "GNC",
            date: "2024-12-11",
            total: 151.33,
            category: "Pharmacy",
            items: [
                ExpenseItem(name: "Creatine", quantity: 1, price: 49.99),
                ExpenseItem(name: "Vitamins", quantity: 1, price: 24.99),
                ExpenseItem(name: "Protein", quantity: 1, price: 76.35),
            ]
        ),
        Expense(
            merchant: "CVS Pharmacy",
            date: "2022-06-06",
            total: 8.48,
            category: "Gifts",
            items: [
                ExpenseItem(name: "Birthday Card", quantity: 1, price: 8.48),
            ]
        ),
        Expense(
            merchant: "Target",
            date: "2021-08-19",
            total: 21.97,
            category: "Haircare",
            items: [
                ExpenseItem(name: "Dove Shampoo", quantity: 1, price: 12.98),
                ExpenseItem(name: "Dove Conditioner", quantity: 1, price: 8.99),
            ],
            groups: [
                ExpenseGroup(
                    category: "Haircare",
                    items: [
                        ExpenseItem(name: "Dove Shampoo", quantity: 1, price: 12.98),
                        ExpenseItem(name: "Dove Conditioner", quantity: 1, price: 8.99),
                    ],
                    total: 21.97
                ),
            ]
        ),
    ]
}
