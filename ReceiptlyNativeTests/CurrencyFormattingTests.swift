import XCTest
@testable import ReceiptlyNative

final class CurrencyFormattingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppPreferences.appLanguageKey)
    }

    func testFormatConvertedAmountIncludesBaseAndOriginalWhenCurrenciesDiffer() {
        let text = formatConvertedAmount(
            originalAmount: 50_000,
            originalCurrency: "KZT",
            convertedAmount: 100,
            convertedCurrency: "USD"
        )

        XCTAssertTrue(text.contains("$100.00"))
        XCTAssertTrue(text.contains("₸50,000.00"))
        XCTAssertTrue(text.contains("("))
    }

    func testExpenseDisplayAmountFallsBackToOriginalWhenNoMatchingSnapshotExists() {
        let expense = makeExpense(
            total: 50_000,
            currency: "KZT",
            convertedTotal: 100,
            convertedCurrency: "EUR",
            exchangeRate: 0.002
        )

        let text = expense.displayAmountText(for: expense.total, baseCurrency: "USD")

        XCTAssertEqual(text, "₸50,000.00")
    }

    func testExpenseDisplayAmountIncludesOriginalCurrencyInParenthesesWhenBaseDiffers() {
        let expense = makeExpense(
            total: 4.99,
            currency: "USD",
            convertedTotal: 2_420,
            convertedCurrency: "KZT",
            exchangeRate: 485.0
        )

        let text = expense.displayAmountText(for: expense.total, baseCurrency: "KZT")

        XCTAssertTrue(text.contains("₸"))
        XCTAssertTrue(text.contains("$4.99"))
        XCTAssertTrue(text.contains("("))
    }
}
