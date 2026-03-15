import SwiftUI

enum Tab: String, CaseIterable {
    case home
    case categories
    case settings

    var icon: String {
        switch self {
        case .home: return "house"
        case .categories: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .home: return loc("Home", "Главная")
        case .categories: return loc("Categories", "Категории")
        case .settings: return loc("Settings", "Настройки")
        }
    }
}

private struct ExpenseSelection: Identifiable, Equatable {
    let expense: Expense
    let categoryFilter: String?

    var id: String {
        "\(expense.id)|\(categoryFilter ?? "")"
    }
}

private struct PendingDeletion {
    let expense: Expense
}

@MainActor
struct ContentView: View {
    @AppStorage(AppPreferences.baseCurrencyKey) private var baseCurrencyRawValue = BaseCurrencyOption.usd.rawValue
    @StateObject private var store: ExpenseStore
    @StateObject private var workflow: ReceiptWorkflow
    private let exchangeRates: any ExchangeRateProviding
    private let authStore: AuthStore?

    @State private var tab: Tab = .home
    @State private var categoryPath: [String] = []
    @State private var showUploadSheet = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var detailSelection: ExpenseSelection? = nil
    @State private var pendingDeletion: PendingDeletion? = nil
    @State private var isUndoBannerVisible = false
    @State private var deleteUndoTask: Task<Void, Never>? = nil
    @State private var showNotReceipt = false
    @State private var errorMsg: String? = nil
    @State private var stagingAddMore = false
    @State private var isRefreshingCurrency = false
    @State private var currencyRefreshMessage: String? = nil

    init(dependencies: AppDependencies = .live(), authStore: AuthStore? = nil, initialTab: Tab = .home) {
        let store = ExpenseStore(repository: dependencies.repository)
        self.init(
            store: store,
            analyzer: dependencies.analyzer,
            exchangeRates: dependencies.exchangeRates,
            authStore: authStore,
            initialTab: initialTab
        )
    }

    init(
        store: ExpenseStore,
        analyzer: any ReceiptAnalyzing,
        exchangeRates: any ExchangeRateProviding,
        authStore: AuthStore? = nil,
        initialTab: Tab = .home
    ) {
        _store = StateObject(wrappedValue: store)
        _workflow = StateObject(wrappedValue: ReceiptWorkflow(store: store, analyzer: analyzer, exchangeRates: exchangeRates))
        self.exchangeRates = exchangeRates
        self.authStore = authStore
        _tab = State(initialValue: initialTab)
    }

    private var stagingBinding: Binding<Bool> {
        Binding(
            get: {
                if case .staging = workflow.step {
                    return true
                }
                return false
            },
            set: { _ in }
        )
    }

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: {
                if case .confirming = workflow.step { return true }
                if case .editing = workflow.step { return true }
                return false
            },
            set: { _ in }
        )
    }

    private var stagingSheetHeight: CGFloat {
        max(470, min(UIScreen.main.bounds.height * 0.60, 520))
    }

    private var uploadSheetHeight: CGFloat {
        max(300, min(UIScreen.main.bounds.height * 0.36, 320))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMsg != nil },
            set: { isPresented in
                if !isPresented {
                    errorMsg = nil
                }
            }
        )
    }

    var body: some View {
        rootContent
            .tint(AppColor.accent)
            .sheet(isPresented: $showUploadSheet) {
                uploadSheet(onClose: { showUploadSheet = false })
                    .presentationDetents([.height(uploadSheetHeight)])
            }
            .fullScreenCover(isPresented: $showCamera) {
                cameraPicker
            }
            .fullScreenCover(isPresented: $showLibrary) {
                libraryPicker
            }
            .sheet(isPresented: stagingBinding) {
                stagingSheet
            }
            .fullScreenCover(isPresented: confirmBinding) {
                confirmFlow
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let pendingDeletion {
                    UndoDeleteBanner(
                        expense: pendingDeletion.expense,
                        isVisible: isUndoBannerVisible,
                        onUndo: undoPendingDeletion
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
            .sheet(item: $detailSelection) { selection in
                expenseDetailSheet(for: selection)
            }
            .alert(loc("That doesn’t look like a receipt", "Это не похоже на чек"), isPresented: $showNotReceipt) {
                Button(loc("Try Again", "Попробовать снова")) { showUploadSheet = true }
                Button(loc("Cancel", "Отмена"), role: .cancel) {}
            } message: {
                Text(loc(
                    "Try another photo or capture the full receipt with better lighting.",
                    "Попробуй другое фото или сними чек целиком при лучшем освещении."
                ))
            }
            .alert(loc("Something went wrong", "Что-то пошло не так"), isPresented: errorBinding, presenting: errorMsg) { _ in
                Button(loc("OK", "ОК"), role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onChange(of: workflow.notReceiptDetected) { detected in
                if detected {
                    showNotReceipt = true
                    workflow.notReceiptDetected = false
                }
            }
            .onChange(of: workflow.errorMessage) { message in
                if let message {
                    errorMsg = message
                    workflow.errorMessage = nil
                }
            }
            .task {
                await store.loadIfNeeded()
            }
            .task(id: baseCurrencyRawValue) {
                await store.loadIfNeeded()
                await refreshCurrencySnapshots()
            }
    }

    private var rootContent: some View {
        TabView(selection: $tab) {
            homeTab
                .tabItem { Label(Tab.home.label, systemImage: Tab.home.icon) }
                .tag(Tab.home)

            categoriesTab
                .tabItem { Label(Tab.categories.label, systemImage: Tab.categories.icon) }
                .tag(Tab.categories)

            settingsTab
                .tabItem { Label(Tab.settings.label, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
    }

    private var homeTab: some View {
        NavigationStack {
            HomeView(
                expenses: store.expenses,
                stats: store.stats,
                isLoading: workflow.isLoading,
                flash: workflow.flash,
                isFlashVisible: workflow.isFlashVisible,
                onScanPress: { showUploadSheet = true },
                onManualPress: { workflow.startManualEntry() },
                onFlashPress: selectExpense,
                onExpensePress: selectExpense,
                onDeletePress: requestDeleteExpense,
                onRefresh: { await store.reload() }
            )
            .navigationTitle("Marty")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var categoriesTab: some View {
        NavigationStack(path: $categoryPath) {
            CategoriesView(
                stats: store.stats,
                onCategoryPress: { categoryPath.append($0) },
                onRefresh: { await store.reload() }
            )
            .navigationTitle(loc("Categories", "Категории"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { category in
                CategoryDetailView(
                    category: category,
                    expenses: store.expenses,
                    baseCurrency: store.stats.displayCurrency,
                    onExpensePress: { expense, filter in
                        detailSelection = ExpenseSelection(expense: expense, categoryFilter: filter)
                    },
                    onDeletePress: requestDeleteExpense
                )
            }
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            SettingsView(
                authStore: authStore,
                expenses: store.expenses,
                stats: store.stats,
                isRefreshingCurrency: isRefreshingCurrency,
                currencyRefreshMessage: currencyRefreshMessage,
                onClearAll: { store.clearAll() }
            )
            .navigationTitle(loc("Settings", "Настройки"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var cameraPicker: some View {
        CameraPicker(
            onCapture: { image in
                showCamera = false
                workflow.stageImage(StagedImage(uiImage: image))
            },
            onCancel: { showCamera = false }
        )
        .ignoresSafeArea()
    }

    private var libraryPicker: some View {
        PhotoLibraryPicker { image in
            showLibrary = false
            workflow.stageImage(StagedImage(uiImage: image))
        }
        .ignoresSafeArea()
    }

    private var stagingSheet: some View {
        Group {
            if case .staging(let images) = workflow.step {
                ImageStagingView(
                    images: images,
                    onAddMore: { stagingAddMore = true },
                    onRemove: { workflow.removeStaged(at: $0) },
                    onAnalyze: { workflow.startAnalysis(images: images) },
                    onCancel: { workflow.clearStaged() }
                )
            }
        }
        .presentationDetents([.height(stagingSheetHeight), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $stagingAddMore) {
            uploadSheet(onClose: { stagingAddMore = false })
                .presentationDetents([.height(uploadSheetHeight)])
        }
    }

    private var confirmFlow: some View {
        Group {
            if case .confirming(let groups) = workflow.step {
                ReceiptConfirmView(
                    groups: groups,
                    onConfirm: { workflow.confirmReceipt(editedGroups: $0) },
                    onDiscard: { workflow.discardPending() }
                )
            } else if case .editing(let expense, let groups) = workflow.step {
                ReceiptConfirmView(
                    groups: groups,
                    onConfirm: { workflow.saveEdit(expense: expense, editedGroups: $0) },
                    onDiscard: { workflow.discardEdit() }
                )
            }
        }
    }

    private func uploadSheet(onClose: @escaping () -> Void) -> some View {
        UploadSheetView(
            onCamera: {
                onClose()
                presentCamera()
            },
            onLibrary: {
                onClose()
                presentLibrary()
            },
            onClose: onClose
        )
    }

    private func expenseDetailSheet(for selection: ExpenseSelection) -> some View {
        ExpenseDetailView(
            expense: selection.expense,
            baseCurrency: store.stats.displayCurrency,
            categoryFilter: selection.categoryFilter,
            onDelete: { id in
                closeDetailThen {
                    requestDeleteExpense(id: id)
                }
            },
            onEdit: { expense in
                closeDetailThen {
                    workflow.startEdit(expense)
                }
            },
            onCategoryPress: { category in
                detailSelection = nil
                tab = .categories
                categoryPath = [category]
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func selectExpense(_ expense: Expense) {
        detailSelection = ExpenseSelection(expense: expense, categoryFilter: nil)
    }

    private func presentCamera() {
        UIActionScheduler.perform(after: UIActionDelay.modalTransitionSeconds) {
            showCamera = true
        }
    }

    private func presentLibrary() {
        UIActionScheduler.perform(after: UIActionDelay.modalTransitionSeconds) {
            showLibrary = true
        }
    }

    private func closeDetailThen(_ action: @escaping @MainActor () -> Void) {
        detailSelection = nil
        UIActionScheduler.perform(after: UIActionDelay.followUpActionSeconds) {
            action()
        }
    }

    private func requestDeleteExpense(id: String) {
        guard let expense = store.expenses.first(where: { $0.id == id }) else { return }

        deleteUndoTask?.cancel()

        if detailSelection?.expense.id == id {
            detailSelection = nil
        }

        pendingDeletion = PendingDeletion(expense: expense)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            store.delete(id: id)
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isUndoBannerVisible = true
        }

        deleteUndoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UIActionDelay.undoBannerLifetimeNanoseconds)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.22)) {
                isUndoBannerVisible = false
            }

            try? await Task.sleep(nanoseconds: UIActionDelay.bannerHideAnimationNanoseconds)
            guard !Task.isCancelled else { return }

            pendingDeletion = nil
        }
    }

    private func undoPendingDeletion() {
        guard let pendingDeletion else { return }

        deleteUndoTask?.cancel()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            store.add(pendingDeletion.expense)
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isUndoBannerVisible = false
        }

        deleteUndoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UIActionDelay.bannerHideAnimationNanoseconds)
            guard !Task.isCancelled else { return }

            self.pendingDeletion = nil
        }
    }
}

extension ContentView {
    private func refreshCurrencySnapshots() async {
        guard !store.expenses.isEmpty else {
            store.refreshStats()
            currencyRefreshMessage = nil
            return
        }

        isRefreshingCurrency = true
        defer { isRefreshingCurrency = false }

        let result = await store.refreshCurrencySnapshots(
            using: exchangeRates,
            baseCurrency: normalizedCurrencyCode(baseCurrencyRawValue)
        )

        switch result {
        case .updated, .noExpenses:
            currencyRefreshMessage = nil
        case .aborted:
            currencyRefreshMessage = loc(
                "Could not update the new base currency right now. Existing totals stay in the previous currency until exchange rates load.",
                "Не удалось пересчитать новую базовую валюту прямо сейчас. Текущие суммы останутся в предыдущей валюте, пока не загрузятся курсы."
            )
        }
    }
}

#Preview("App - Home") {
    ContentView(dependencies: .preview(), initialTab: .home)
}

#Preview("App - Categories") {
    ContentView(dependencies: .preview(), initialTab: .categories)
}

#Preview("App - Settings") {
    ContentView(dependencies: .preview(), initialTab: .settings)
}
