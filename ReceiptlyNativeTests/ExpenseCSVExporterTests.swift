import XCTest
@testable import ReceiptlyNative

final class ExpenseCSVExporterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppPreferences.appLanguageKey)
    }

    func testCSVExporterProducesExpectedRowsAndSanitizesCells() {
        let expenses = [
            makeExpense(
                merchant: "=Danger Mart",
                date: "2024-12-11",
                total: 21.97,
                currency: "KZT",
                category: "Groceries",
                items: [
                    makeExpenseItem(name: "Milk", quantity: 1, price: 3.50),
                    makeExpenseItem(name: "Eggs, large", quantity: 1, price: 4.75),
                ],
                convertedTotal: 0.04,
                convertedCurrency: "USD",
                exchangeRate: 0.001822
            ),
        ]

        let csv = ExpenseCSVExporter.csvString(from: expenses)

        XCTAssertEqual(
            csv,
            """
            "Date","Merchant","Category","Original Total","Original Currency","Base Total","Base Currency","Exchange Rate","Items"
            "2024-12-11","'=Danger Mart","Groceries","21.97","KZT","0.04","USD","0.001822","Milk; Eggs, large"
            """
        )
    }
}
