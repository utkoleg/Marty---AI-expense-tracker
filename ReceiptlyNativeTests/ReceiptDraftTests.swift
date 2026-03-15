import XCTest
@testable import ReceiptlyNative

final class ReceiptDraftTests: XCTestCase {
    func testBuildReceiptGroupsSanitizesDraftValues() {
        var invalidPriceItem = EditableItem(name: "", price: 0, quantity: 1)
        invalidPriceItem.price = "oops"

        var draft = ReceiptDraft(groups: [])
        draft.merchant = "  Target  "
        draft.date = "2024-13-99"
        draft.currency = "usd"
        draft.notes = "  hi\r\n\r\nthere "
        draft.groups = [
            EditableGroup(
                category: "Unknown category",
                items: [
                    EditableItem(name: "  Vitamins ", price: 12.50, quantity: 1),
                    invalidPriceItem,
                ]
            ),
        ]

        let groups = draft.buildReceiptGroups()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].merchant, "Target")
        XCTAssertEqual(groups[0].date, todayString())
        XCTAssertEqual(groups[0].currency, "USD")
        XCTAssertEqual(groups[0].notes, "hi\n\nthere")
        XCTAssertEqual(groups[0].category, "Other")
        XCTAssertEqual(groups[0].items.count, 2)
        XCTAssertEqual(groups[0].items[0].name, "Vitamins")
        XCTAssertEqual(groups[0].items[1].price.value, 0)
    }

    func testMoveItemTransfersAcrossGroupsAndRemovesEmptySource() {
        let milk = EditableItem(name: "Milk", price: 3.50)
        let vitamins = EditableItem(name: "Vitamins", price: 12.00)
        var draft = ReceiptDraft(groups: [])
        draft.groups = [
            EditableGroup(category: "Groceries", items: [milk]),
            EditableGroup(category: "Pharmacy", items: [vitamins]),
        ]

        let moved = draft.moveItem(milk.id, to: draft.groups[1].id)

        XCTAssertTrue(moved)
        XCTAssertEqual(draft.groups.count, 1)
        XCTAssertEqual(draft.groups[0].category, "Pharmacy")
        XCTAssertEqual(draft.groups[0].items.map(\.name), ["Vitamins", "Milk"])
    }

    func testValidationFlagsMissingMerchantDateAndItemValues() {
        var invalidItem = EditableItem(name: "", price: 0, quantity: 1)
        invalidItem.price = ""

        var draft = ReceiptDraft(groups: [])
        draft.merchant = " "
        draft.date = "2024/01/01"
        draft.groups = [
            EditableGroup(
                category: "Other",
                items: [invalidItem]
            ),
        ]

        XCTAssertEqual(draft.merchantValidationMessage, "Enter merchant name")
        XCTAssertEqual(draft.dateValidationMessage, "Use YYYY-MM-DD")
        XCTAssertTrue(draft.hasValidationErrors)
    }

    func testInitMergesDuplicateCategoriesFromAnalyzer() {
        let draft = ReceiptDraft(groups: [
            makeReceiptGroup(
                merchant: "Protein Shop",
                date: "2025-08-13",
                currency: "KZT",
                notes: "",
                category: "Gym",
                items: [ReceiptGroup.RawItem(name: "Creatine", quantity: 1, price: FlexDouble(7_940))],
                total: 7_940
            ),
            makeReceiptGroup(
                merchant: "Protein Shop",
                date: "2025-08-13",
                currency: "KZT",
                notes: "",
                category: "Gym",
                items: [ReceiptGroup.RawItem(name: "Whey", quantity: 1, price: FlexDouble(17_940))],
                total: 17_940
            ),
        ])

        XCTAssertEqual(draft.groups.count, 1)
        XCTAssertEqual(draft.groups[0].category, "Gym")
        XCTAssertEqual(draft.groups[0].items.map(\.name), ["Creatine", "Whey"])
        XCTAssertEqual(draft.total, 25_880)
    }

    func testSetCategoryMergesIntoExistingCategoryGroup() {
        var draft = ReceiptDraft(groups: [])
        draft.groups = [
            EditableGroup(category: "Gym", items: [EditableItem(name: "Creatine", price: 7_940)]),
            EditableGroup(category: "Other", items: [EditableItem(name: "Whey", price: 17_940)]),
        ]

        let otherID = draft.groups[1].id
        draft.setCategory("Gym", for: otherID)

        XCTAssertEqual(draft.groups.count, 1)
        XCTAssertEqual(draft.groups[0].category, "Gym")
        XCTAssertEqual(draft.groups[0].items.map(\.name), ["Creatine", "Whey"])
        XCTAssertEqual(draft.groups[0].total, 25_880)
    }
}
