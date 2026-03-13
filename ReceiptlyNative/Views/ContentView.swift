import SwiftUI

// MARK: - Tab definition

enum Tab: String, CaseIterable {
    case categories = "categories"
    case home       = "home"
    case settings   = "settings"

    var icon: String {
        switch self {
        case .categories: return "chart.pie"
        case .home:       return "house"
        case .settings:   return "gearshape"
        }
    }

    var activeIcon: String {
        switch self {
        case .categories: return "chart.pie.fill"
        case .home:       return "house.fill"
        case .settings:   return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .categories: return "Categories"
        case .home:       return "Home"
        case .settings:   return "Settings"
        }
    }
}

// MARK: - ContentView

@MainActor
struct ContentView: View {

    @StateObject private var store: ExpenseStore
    @StateObject private var workflow: ReceiptWorkflow

    init(initialTab: Tab = .home) {
        let defaultStore = ExpenseStore()
        _store = StateObject(wrappedValue: defaultStore)
        _workflow = StateObject(wrappedValue: ReceiptWorkflow(store: defaultStore))
        _tab = State(initialValue: initialTab)
    }

    init(store: ExpenseStore, initialTab: Tab = .home) {
        _store = StateObject(wrappedValue: store)
        _workflow = StateObject(wrappedValue: ReceiptWorkflow(store: store))
        _tab = State(initialValue: initialTab)
    }

    // Navigation
    @State private var tab: Tab = .home
    @State private var activeCat: String? = nil
    @State private var showingDetail = false      // category detail

    // Overlays
    @State private var showUploadSheet = false
    @State private var showCamera      = false
    @State private var showLibrary     = false
    @State private var detailExpense: Expense?    = nil
    @State private var detailCatFilter: String?   = nil
    @State private var deleteTarget: String?      = nil
    @State private var showNotReceipt  = false
    @State private var errorMsg: String?          = nil

    // Navbar visibility — driven by explicit @State, not computed, for reliable SwiftUI updates
    @State private var navHidden = false

    // Staging "Add More" sheet (separate from the main upload sheet)
    @State private var stagingAddMore = false

    // Pager drag state
    @State private var pageDragOffset: CGFloat = 0
    @State private var isPageDragging = false

    // MARK: - Sheet bindings

    private var stagingBinding: Binding<Bool> {
        Binding(
            get: { if case .staging = workflow.step { return true } else { return false } },
            set: { _ in }   // dismissed only via Cancel button
        )
    }

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: {
                if case .confirming = workflow.step { return true }
                if case .editing    = workflow.step { return true }
                return false
            },
            set: { _ in }   // dismissed only via Discard button
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .background(AppColor.bg)
                    .opacity(navHidden ? 0 : 1)
                    .allowsHitTesting(!navHidden)
                    .animation(.easeInOut(duration: 0.15), value: navHidden)

                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !navHidden {
                tabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            // Overlays
            overlays
        }
        .animation(.easeInOut(duration: 0.15), value: navHidden)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showUploadSheet) {
            UploadSheetView(
                onCamera: {
                    showUploadSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showCamera = true }
                },
                onLibrary: {
                    showUploadSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showLibrary = true }
                },
                onClose: { showUploadSheet = false }
            )
            .presentationDetents([.height(280)])
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { img in
                    showCamera = false
                    workflow.stageImage(StagedImage(uiImage: img))
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showLibrary) {
            PhotoLibraryPicker { img in
                showLibrary = false
                workflow.stageImage(StagedImage(uiImage: img))
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: stagingBinding) {
            Group {
                if case .staging(let imgs) = workflow.step {
                    ImageStagingView(
                        images: imgs,
                        onAddMore: { stagingAddMore = true },
                        onRemove: { workflow.removeStaged(at: $0) },
                        onAnalyze: { workflow.startAnalysis(images: imgs) },
                        onCancel:  { workflow.clearStaged() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.surface)
            .interactiveDismissDisabled()
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.hidden)
            .sheet(isPresented: $stagingAddMore) {
                UploadSheetView(
                    onCamera: {
                        stagingAddMore = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showCamera = true }
                    },
                    onLibrary: {
                        stagingAddMore = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showLibrary = true }
                    },
                    onClose: { stagingAddMore = false }
                )
                .presentationDetents([.height(280)])
            }
        }
        .fullScreenCover(isPresented: confirmBinding) {
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
        .onChange(of: detailExpense)    { navHidden = $0 != nil }
        .onChange(of: deleteTarget)     { navHidden = $0 != nil }
        .onChange(of: showNotReceipt)   { navHidden = $0 }
        .onChange(of: errorMsg)         { navHidden = $0 != nil }
        .onChange(of: tab) {
            if $0 != .categories { showingDetail = false }
            if !isPageDragging { pageDragOffset = 0 }
        }
        .onChange(of: workflow.notReceiptDetected) { detected in
            if detected { showNotReceipt = true; workflow.notReceiptDetected = false }
        }
        .onChange(of: workflow.errorMessage) { msg in
            if let m = msg { errorMsg = m; workflow.errorMessage = nil }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(alignment: .bottom) {
            HStack(alignment: .center, spacing: 12) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Marty")
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(AppColor.text)
                    Text(navSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColor.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(AppColor.bg)
        .overlay(alignment: .bottom) {
            Divider().background(AppColor.border)
        }
    }

    private var navSubtitle: String {
        switch tab {
        case .home:       return "\(store.expenses.count) expenses"
        case .categories:
            if showingDetail, let cat = activeCat { return cat }
            return "\(store.stats.usedCats.count) categories"
        case .settings:   return "Settings"
        }
    }

    // MARK: - Pages

    private var pagerTabs: [Tab] { [.categories, .home, .settings] }
    private var currentPageIndex: Int { pagerTabs.firstIndex(of: tab) ?? 1 }

    private var pageContent: some View {
        GeometryReader { proxy in
            let pageWidth = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                page(for: .categories)
                    .frame(width: pageWidth)
                    .scrollDisabled(isPageDragging)
                page(for: .home)
                    .frame(width: pageWidth)
                    .scrollDisabled(isPageDragging)
                page(for: .settings)
                    .frame(width: pageWidth)
                    .scrollDisabled(isPageDragging)
            }
            .frame(width: pageWidth * CGFloat(pagerTabs.count), alignment: .leading)
            .offset(x: (-CGFloat(currentPageIndex) * pageWidth) + pageDragOffset)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(pagerDragGesture(pageWidth: pageWidth))
        }
    }

    @ViewBuilder
    private func page(for targetTab: Tab) -> some View {
        switch targetTab {
        case .home:
            HomeView(
                expenses: store.expenses,
                stats: store.stats,
                isLoading: workflow.isLoading,
                flash: workflow.flash,
                onScanPress: { showUploadSheet = true },
                onExpensePress: { exp in withAnimation(.easeInOut(duration: 0.2)) { detailExpense = exp; detailCatFilter = nil } },
                onDeletePress: { id in withAnimation(.easeInOut(duration: 0.2)) { deleteTarget = id } },
                onRefresh: { store.reload() }
            )

        case .categories:
            if showingDetail, let cat = activeCat {
                CategoryDetailView(
                    category: cat,
                    expenses: store.expenses,
                    onBack: { withAnimation { showingDetail = false } },
                    onExpensePress: { exp, c in withAnimation(.easeInOut(duration: 0.2)) { detailExpense = exp; detailCatFilter = c } },
                    onDeletePress: { id in withAnimation(.easeInOut(duration: 0.2)) { deleteTarget = id } }
                )
            } else {
                CategoriesView(
                    stats: store.stats,
                    onCategoryPress: { cat in activeCat = cat; withAnimation { showingDetail = true } },
                    onRefresh: { store.reload() }
                )
            }

        case .settings:
            SettingsView(
                expenses: store.expenses,
                stats: store.stats,
                onClearAll: { store.clearAll() }
            )
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        VStack(spacing: 0) {
            Divider().background(AppColor.border.opacity(0.72))

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    let active = t == tab || (t == .categories && showingDetail && tab == .categories)
                    Button {
                        Haptics.light()
                        if t == .categories { showingDetail = false }
                        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.92)) {
                            tab = t
                            pageDragOffset = 0
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: active ? t.activeIcon : t.icon)
                                .font(.system(size: 20, weight: active ? .semibold : .regular))

                            Text(t.label)
                                .font(.system(size: 10.5, weight: active ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(active ? AppColor.accent : AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 9)
                        .contentShape(Rectangle())
                        .animation(.easeInOut(duration: 0.18), value: active)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background {
            BlurView(style: .systemUltraThinMaterial)
                .overlay(AppColor.surface.opacity(0.14))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Pager gesture

    private func pagerDragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let absX = abs(dx)
                let absY = abs(dy)

                // Engage pager only when horizontal intent is clear, then lock vertical scroll.
                if !isPageDragging {
                    guard absX > 6, absX > absY else { return }
                    isPageDragging = true
                }

                let atFirst = currentPageIndex == 0
                let atLast = currentPageIndex == (pagerTabs.count - 1)

                var drag = dx
                if (atFirst && dx > 0) || (atLast && dx < 0) {
                    // Rubber-band at edges.
                    drag = dx * 0.28
                }
                pageDragOffset = max(-pageWidth, min(pageWidth, drag))
            }
            .onEnded { value in
                defer {
                    isPageDragging = false
                }

                guard isPageDragging else { return }

                let dx = value.translation.width
                let projected = value.predictedEndTranslation.width
                let threshold = pageWidth * 0.42
                var nextIndex = currentPageIndex

                if dx < -threshold || projected < -threshold {
                    nextIndex += 1
                } else if dx > threshold || projected > threshold {
                    nextIndex -= 1
                }

                nextIndex = min(max(nextIndex, 0), pagerTabs.count - 1)

                withAnimation(.interactiveSpring(response: 0.52, dampingFraction: 0.94)) {
                    tab = pagerTabs[nextIndex]
                    pageDragOffset = 0
                }
            }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlays: some View {
        // Expense detail
        if let exp = detailExpense {
            ExpenseDetailView(
                expense: exp,
                categoryFilter: detailCatFilter,
                onClose: { withAnimation(.easeInOut(duration: 0.2)) { detailExpense = nil; detailCatFilter = nil } },
                onDelete: { id in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        detailExpense = nil
                        detailCatFilter = nil
                        deleteTarget = id
                    }
                },
                onEdit: { e in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        detailExpense = nil
                        detailCatFilter = nil
                    }
                    workflow.startEdit(e)
                },
                onCategoryPress: { cat in
                    detailExpense = nil
                    detailCatFilter = nil
                    activeCat = cat
                    showingDetail = true
                    tab = .categories
                }
            )
            .zIndex(5)
            .transition(.opacity)
        }

        // Delete confirm
        if let id = deleteTarget {
            ConfirmDialog(
                title: "Delete expense?",
                message: "This cannot be undone.",
                confirmLabel: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if detailExpense?.id == id { detailExpense = nil }
                        store.delete(id: id)
                        deleteTarget = nil
                    }
                },
                onCancel: { withAnimation(.easeInOut(duration: 0.2)) { deleteTarget = nil } }
            )
            .zIndex(6)
            .animation(.easeOut(duration: 0.15), value: deleteTarget != nil)
        }

        // Not-a-receipt modal
        if showNotReceipt {
            NotReceiptModal(
                onRetry: { showNotReceipt = false; showUploadSheet = true },
                onClose: { showNotReceipt = false }
            )
            .zIndex(7)
        }

        // Error modal
        if let msg = errorMsg {
            ErrorModal(message: msg, onClose: { errorMsg = nil })
                .zIndex(8)
        }
    }
}

// MARK: - Not-a-receipt modal

private struct NotReceiptModal: View {
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            AppColor.scrim.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🤔").font(.system(size: 48))
                Text("Not a receipt")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColor.text)
                Text("The image doesn't appear to be a receipt or invoice.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Close", action: onClose)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(AppColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.muted).fontWeight(.semibold)
                    Button("Try Again", action: onRetry)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(AppColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.onAccent).fontWeight(.bold)
                }
            }
            .padding(24)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
    }
}

// MARK: - Error modal

private struct ErrorModal: View {
    let message: String
    var onClose: () -> Void

    var body: some View {
        ZStack {
            AppColor.scrim.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("⚠️").font(.system(size: 40))
                Text("Something went wrong")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColor.text)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.muted)
                    .multilineTextAlignment(.center)
                Button("OK", action: onClose)
                    .frame(maxWidth: .infinity).padding(12)
                    .background(AppColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                    .foregroundColor(AppColor.onAccent).fontWeight(.bold)
            }
            .padding(24)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
    }
}

// MARK: - Whole app previews

#Preview("App - Home") {
    ContentView(store: .previewStore(), initialTab: .home)
}

#Preview("App - Categories") {
    ContentView(store: .previewStore(), initialTab: .categories)
}

#Preview("App - Settings") {
    ContentView(store: .previewStore(), initialTab: .settings)
}

private extension ExpenseStore {
    static func previewStore() -> ExpenseStore {
        ExpenseStore(previewExpenses: [
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
        ])
    }
}
