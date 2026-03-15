import XCTest
@testable import ReceiptlyNative

final class ExpenseMapperTests: XCTestCase {
    func testBuildExpenseNormalizesInputAndChoosesDominantCategory() {
        let groups = [
            makeReceiptGroup(
                merchant: "  Target  ",
                date: "2024-13-40",
                currency: "usd",
                notes: " hi\r\n\r\n\r\nthere ",
                category: "Groceries",
                items: [
                    ReceiptGroup.RawItem(name: "  Milk ", quantity: 0, price: FlexDouble(2.50)),
                    ReceiptGroup.RawItem(name: " ", quantity: 1, price: FlexDouble(9.99)),
                ],
                total: nil
            ),
            makeReceiptGroup(
                merchant: "Ignored",
                date: "2024-12-11",
                currency: "usd",
                notes: "",
                category: "Unknown category",
                items: [
                    ReceiptGroup.RawItem(name: " Vitamins ", quantity: 2_000, price: FlexDouble(4.50)),
                ],
                total: 1_000_000
            ),
        ]

        let expense = buildExpense(from: groups)

        XCTAssertEqual(expense.merchant, "Target")
        XCTAssertEqual(expense.date, todayString())
        XCTAssertEqual(expense.currency, "USD")
        XCTAssertEqual(expense.notes, "hi\n\nthere")
        XCTAssertEqual(expense.category, "Other")
        XCTAssertEqual(expense.total, InputLimits.maxPrice)
        XCTAssertEqual(expense.items.map(\.name), ["Milk", "Vitamins"])
        XCTAssertEqual(expense.items.map(\.quantity), [1, InputLimits.maxQuantity])
        XCTAssertEqual(expense.groups?.count, 2)
        XCTAssertEqual(expense.groups?.first?.total, 2.50)
        XCTAssertEqual(expense.groups?.last?.category, "Other")
        XCTAssertEqual(expense.groups?.last?.total, InputLimits.maxPrice)
    }

    func testBuildExpenseKeepsSingleCategoryExpensesFlat() {
        let expense = buildExpense(from: [
            makeReceiptGroup(
                merchant: "Whole Foods",
                date: "2024-12-01",
                currency: "usd",
                notes: "weekly groceries",
                category: "Groceries",
                items: [
                    ReceiptGroup.RawItem(name: "Eggs", quantity: 2, price: FlexDouble(6.00)),
                    ReceiptGroup.RawItem(name: "Bread", quantity: 1, price: FlexDouble(4.00)),
                ],
                total: nil
            ),
        ])

        XCTAssertEqual(expense.category, "Groceries")
        XCTAssertNil(expense.groups)
        XCTAssertEqual(expense.total, 10)
        XCTAssertEqual(expense.items.count, 2)
    }

    func testExpenseToGroupsUsesMultiCategoryGroupsWhenPresent() {
        let expense = makeExpense(
            merchant: "Target",
            date: "2024-12-11",
            total: 30,
            category: "Groceries",
            items: [
                makeExpenseItem(name: "Milk", quantity: 1, price: 10),
                makeExpenseItem(name: "Vitamins", quantity: 1, price: 20),
            ],
            notes: "split purchase",
            groups: [
                makeExpenseGroup(
                    category: "Groceries",
                    items: [makeExpenseItem(name: "Milk", quantity: 1, price: 10)],
                    total: 10
                ),
                makeExpenseGroup(
                    category: "Pharmacy",
                    items: [makeExpenseItem(name: "Vitamins", quantity: 1, price: 20)],
                    total: 20
                ),
            ]
        )

        let groups = expenseToGroups(expense)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].merchant, "Target")
        XCTAssertEqual(groups[0].category, "Groceries")
        XCTAssertEqual(groups[0].items.first?.name, "Milk")
        XCTAssertEqual(groups[1].category, "Pharmacy")
        XCTAssertEqual(groups[1].total, 20)
    }

    func testExpenseToGroupsBuildsSingleGroupFromExpenseFields() {
        let expense = makeExpense(
            merchant: "Cafe",
            date: "2024-12-02",
            total: 18,
            category: "Dining",
            items: [makeExpenseItem(name: "Lunch", quantity: 1, price: 18)],
            notes: "solo group",
            groups: nil
        )

        let groups = expenseToGroups(expense)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].merchant, "Cafe")
        XCTAssertEqual(groups[0].date, "2024-12-02")
        XCTAssertEqual(groups[0].category, "Dining")
        XCTAssertEqual(groups[0].items.first?.name, "Lunch")
        XCTAssertEqual(groups[0].total, 18)
    }
}
