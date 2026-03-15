import XCTest
@testable import ReceiptlyNative

final class ExpenseRowTests: XCTestCase {
    func testRoundTripPreservesExpenseContent() {
        let expense = makeExpense(
            id: "expense-row",
            merchant: "Target",
            date: "2024-12-11",
            total: 21.97,
            currency: "USD",
            category: "Haircare",
            items: [
                makeExpenseItem(name: "Shampoo", quantity: 1, price: 12.98),
                makeExpenseItem(name: "Conditioner", quantity: 1, price: 8.99),
            ],
            notes: "weekly run",
            addedAt: "2024-12-11T12:00:00Z",
            groups: [
                makeExpenseGroup(
                    category: "Haircare",
                    items: [
                        makeExpenseItem(name: "Shampoo", quantity: 1, price: 12.98),
                        makeExpenseItem(name: "Conditioner", quantity: 1, price: 8.99),
                    ],
                    total: 21.97
                ),
            ],
            convertedTotal: 21.97,
            convertedCurrency: "USD",
            exchangeRate: 1,
            exchangeRateUpdatedAt: "2024-12-11T12:00:00Z"
        )

        let row = ExpenseRow(expense: expense, userID: "user-123")

        XCTAssertEqual(snapshot(row.asExpense()), snapshot(expense))
    }

    func testEncodingUsesDatabaseFriendlyKeys() throws {
        let row = ExpenseRow(
            expense: makeExpense(id: "expense-row-keys", merchant: "Store"),
            userID: "user-123"
        )

        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any]
        )

        XCTAssertEqual(payload["user_id"] as? String, "user-123")
        XCTAssertEqual(payload["expense_date"] as? String, "2024-12-11")
        XCTAssertEqual(payload["added_at"] as? String, "2024-12-11T12:00:00Z")
        XCTAssertNil(payload["userID"])
        XCTAssertNil(payload["expenseDate"])
        XCTAssertNil(payload["addedAt"])
    }
}
