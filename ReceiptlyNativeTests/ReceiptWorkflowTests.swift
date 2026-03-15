import XCTest
@testable import ReceiptlyNative

@MainActor
final class ReceiptWorkflowTests: XCTestCase {
    private let exchangeRates = StubExchangeRateService(outcome: .success(0.002))

    func testStartAnalysisSuccessTransitionsToConfirming() async {
        let analyzer = StubReceiptAnalyzer(outcome: .success([makeReceiptGroup()]))
        let workflow = ReceiptWorkflow(
            store: ExpenseStore(repository: SpyExpenseRepository()),
            analyzer: analyzer,
            exchangeRates: exchangeRates
        )

        workflow.startAnalysis(images: [makeStagedImage()])

        await XCTAssertEventually {
            workflow.step == .confirming([]) && workflow.isLoading == false
        }
    }

    func testStartAnalysisNotReceiptSetsFlagAndReturnsIdle() async {
        let analyzer = StubReceiptAnalyzer(outcome: .failure(AnalyzerError.notAReceipt))
        let workflow = ReceiptWorkflow(
            store: ExpenseStore(repository: SpyExpenseRepository()),
            analyzer: analyzer,
            exchangeRates: exchangeRates
        )

        workflow.startAnalysis(images: [makeStagedImage()])

        await XCTAssertEventually {
            workflow.step == .idle && workflow.notReceiptDetected && workflow.isLoading == false
        }
    }

    func testStartAnalysisTimeoutRestoresStagingAndSetsError() async {
        let analyzer = StubReceiptAnalyzer(outcome: .failure(AnalyzerError.timeout))
        let workflow = ReceiptWorkflow(
            store: ExpenseStore(repository: SpyExpenseRepository()),
            analyzer: analyzer,
            exchangeRates: exchangeRates
        )

        workflow.startAnalysis(images: [makeStagedImage()])

        await XCTAssertEventually {
            workflow.step == .staging([]) &&
                workflow.errorMessage == "Request timed out. Check your connection and try again." &&
                workflow.isLoading == false
        }
    }

    func testStartAnalysisGenericErrorRestoresStagingAndSetsError() async {
        let analyzer = StubReceiptAnalyzer(outcome: .failure(TestLocalizedError(message: "boom")))
        let workflow = ReceiptWorkflow(
            store: ExpenseStore(repository: SpyExpenseRepository()),
            analyzer: analyzer,
            exchangeRates: exchangeRates
        )

        workflow.startAnalysis(images: [makeStagedImage()])

        await XCTAssertEventually {
            workflow.step == .staging([]) &&
                workflow.errorMessage == "boom" &&
                workflow.isLoading == false
        }
    }

    func testConfirmReceiptAddsExpenseAndShowsFlash() {
        let repository = SpyExpenseRepository()
        let store = ExpenseStore(repository: repository)
        let workflow = ReceiptWorkflow(
            store: store,
            analyzer: StubReceiptAnalyzer(outcome: .success([])),
            exchangeRates: exchangeRates
        )
        let groups = [
            makeReceiptGroup(
                merchant: "Target",
                date: "2024-12-11",
                currency: "usd",
                notes: "weekly",
                category: "Groceries",
                items: [ReceiptGroup.RawItem(name: "Milk", quantity: 1, price: FlexDouble(3.5))],
                total: 3.5
            ),
        ]

        workflow.confirmReceipt(editedGroups: groups)

        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertEqual(store.expenses.first?.merchant, "Target")
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(workflow.step, WorkflowStep.idle)
        XCTAssertEqual(workflow.flash?.merchant, "Target")
    }

    func testSaveEditUpdatesExistingExpenseAndPreservesAddedAt() {
        let existing = makeExpense(
            id: "expense-1",
            merchant: "Old Merchant",
            date: "2024-01-01",
            total: 5,
            category: "Other",
            items: [makeExpenseItem(name: "Old Item", quantity: 1, price: 5)],
            addedAt: "2024-01-02T00:00:00Z"
        )
        let repository = SpyExpenseRepository(initialExpenses: [existing])
        let store = ExpenseStore(repository: repository)
        let workflow = ReceiptWorkflow(
            store: store,
            analyzer: StubReceiptAnalyzer(outcome: .success([])),
            exchangeRates: exchangeRates
        )
        let updatedGroups = [
            makeReceiptGroup(
                merchant: "New Merchant",
                date: "2024-03-03",
                currency: "usd",
                notes: "updated",
                category: "Dining",
                items: [ReceiptGroup.RawItem(name: "Dinner", quantity: 1, price: FlexDouble(12))],
                total: 12
            ),
        ]

        workflow.startEdit(existing)
        workflow.saveEdit(expense: existing, editedGroups: updatedGroups)

        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertEqual(store.expenses.first?.id, existing.id)
        XCTAssertEqual(store.expenses.first?.addedAt, existing.addedAt)
        XCTAssertEqual(store.expenses.first?.merchant, "New Merchant")
        XCTAssertEqual(store.expenses.first?.category, "Dining")
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(workflow.step, WorkflowStep.idle)
    }
}
