import Foundation
import SwiftUI

// MARK: - Workflow state machine
//
// States:  idle → staging → analyzing → confirming → idle
//          idle → editing → idle

enum WorkflowStep: Equatable {
    case idle
    case staging([StagedImage])
    case analyzing([StagedImage])
    case confirming([ReceiptGroup])
    case editing(Expense, [ReceiptGroup])

    static func == (lhs: WorkflowStep, rhs: WorkflowStep) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.staging, .staging): return true
        case (.analyzing, .analyzing): return true
        case (.confirming, .confirming): return true
        case (.editing, .editing): return true
        default: return false
        }
    }
}

@MainActor
final class ReceiptWorkflow: ObservableObject {

    @Published var step: WorkflowStep = .idle
    @Published var isLoading = false
    @Published var flash: Expense? = nil

    private var analyzeTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?

    // Dependencies
    private let store: ExpenseStore

    init(store: ExpenseStore) {
        self.store = store
    }

    // MARK: - Stage

    func stageImage(_ img: StagedImage) {
        switch step {
        case .staging(let existing):
            step = .staging(existing + [img])
        default:
            step = .staging([img])
        }
    }

    func removeStaged(at index: Int) {
        guard case .staging(let imgs) = step else { return }
        var next = imgs
        next.remove(at: index)
        step = next.isEmpty ? .idle : .staging(next)
    }

    func clearStaged() {
        step = .idle
    }

    // MARK: - Analyze

    func startAnalysis(images: [StagedImage]) {
        analyzeTask?.cancel()
        step = .analyzing(images)
        isLoading = true

        analyzeTask = Task {
            defer { isLoading = false }
            do {
                let groups = try await ReceiptAnalyzer.shared.analyze(images: images)
                guard !Task.isCancelled else { return }
                step = .confirming(groups)
            } catch AnalyzerError.notAReceipt {
                step = .idle
                // Caller observes via notReceiptDetected flag
                notReceiptDetected = true
            } catch AnalyzerError.cancelled {
                // Expected: new analysis started — stay silent
                if case .analyzing = step { step = .idle }
            } catch AnalyzerError.timeout {
                if case .analyzing(let imgs) = step { step = .staging(imgs) }
                errorMessage = "Request timed out. Check your connection and try again."
            } catch {
                if case .analyzing(let imgs) = step { step = .staging(imgs) }
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelAnalysis() {
        analyzeTask?.cancel()
        analyzeTask = nil
        isLoading = false
        if case .analyzing(let imgs) = step { step = .staging(imgs) }
    }

    // MARK: - Confirm new receipt

    func confirmReceipt(editedGroups: [ReceiptGroup]) {
        let expense = buildExpense(from: editedGroups)
        store.add(expense)
        step = .idle
        showFlash(expense)
    }

    func discardPending() {
        step = .idle
    }

    // MARK: - Edit existing expense

    func startEdit(_ expense: Expense) {
        step = .editing(expense, expenseToGroups(expense))
    }

    func saveEdit(expense: Expense, editedGroups: [ReceiptGroup]) {
        var updated = buildExpense(from: editedGroups)
        updated = Expense(
            id: expense.id,
            merchant: updated.merchant,
            date: updated.date,
            total: updated.total,
            currency: updated.currency,
            category: updated.category,
            items: updated.items,
            notes: updated.notes,
            addedAt: expense.addedAt,   // preserve original addedAt
            groups: updated.groups
        )
        store.update(updated)
        step = .idle
    }

    func discardEdit() {
        step = .idle
    }

    // MARK: - Flash notification (5-second auto-dismiss)

    private func showFlash(_ expense: Expense) {
        flashTask?.cancel()
        flash = expense
        flashTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { flash = nil }
        }
    }

    // MARK: - Error & not-receipt signals
    // Observed by ContentView via .onChange

    @Published var errorMessage: String? = nil
    @Published var notReceiptDetected: Bool = false
}
