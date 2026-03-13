import SwiftUI

private let receiptConfirmDragSpace = "receiptConfirmDragSpace"

// MARK: - Editable models (local state during confirm/edit)

struct EditableItem: Identifiable {
    var id: UUID = UUID()
    var name: String
    var price: String   // string for editing
    var quantity: Int

    init(name: String, price: Double, quantity: Int = 1) {
        self.name = name
        self.price = String(format: "%.2f", price)
        self.quantity = quantity
    }
}

struct EditableGroup: Identifiable {
    var id: UUID = UUID()
    var category: String
    var items: [EditableItem]

    var total: Double { items.reduce(0) { $0 + (Double($1.price) ?? 0) } }
}

// MARK: - ReceiptConfirmView

struct ReceiptConfirmView: View {
    let groups: [ReceiptGroup]
    var onConfirm: ([ReceiptGroup]) -> Void
    var onDiscard: () -> Void

    @State private var merchant: String
    @State private var date: String
    @State private var editableGroups: [EditableGroup]
    @State private var catPickerGroupID: UUID? = nil
    @State private var showDiscardConfirm = false
    @State private var activeDrag: ItemDragSession? = nil
    @State private var groupFrames: [UUID: CGRect] = [:]

    init(groups: [ReceiptGroup], onConfirm: @escaping ([ReceiptGroup]) -> Void, onDiscard: @escaping () -> Void) {
        self.groups = groups
        self.onConfirm = onConfirm
        self.onDiscard = onDiscard
        _merchant = State(initialValue: groups.first?.merchant ?? "")
        _date = State(initialValue: groups.first?.date ?? todayString())
        _editableGroups = State(initialValue: groups.map { g in
            EditableGroup(
                category: validCategory(g.category),
                items: g.items.map { i in EditableItem(name: i.name, price: i.resolvedPrice, quantity: i.resolvedQty) }
            )
        })
    }

    private var hasAnyItems: Bool {
        editableGroups.contains { !$0.items.isEmpty }
    }

    private var total: Double { editableGroups.reduce(0) { $0 + $1.total } }

    var body: some View {
        ZStack {
            // Main screen
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Discard") { showDiscardConfirm = true }
                        .foregroundColor(AppColor.danger)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(AppColor.danger.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: Radii.sm).stroke(AppColor.danger.opacity(0.25), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.sm))

                    Spacer()
                    VStack(spacing: 1) {
                        Text("Review Receipt").font(.system(size: 15, weight: .bold)).foregroundColor(AppColor.text)
                        Text("Tap to edit or drag items between categories").font(.system(size: 11)).foregroundColor(AppColor.muted)
                    }
                    Spacer()

                    Button("Save") { handleConfirm() }
                        .foregroundColor(AppColor.onAccent)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(hasAnyItems ? AppColor.accent : AppColor.muted.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
                        .shadow(color: hasAnyItems ? AppColor.accent.opacity(0.35) : .clear, radius: 6)
                        .opacity(hasAnyItems ? 1 : 0.72)
                        .disabled(!hasAnyItems)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(Divider().background(AppColor.border), alignment: .bottom)

                // Scrollable body
                ScrollView {
                    VStack(spacing: 12) {
                        // Merchant + date card
                        VStack(alignment: .leading, spacing: 0) {
                            fieldLabel("Merchant")
                            TextField("Merchant name", text: $merchant)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColor.text)
                                .padding(.bottom, 6)
                                .overlay(Divider().background(AppColor.border), alignment: .bottom)
                                .padding(.bottom, 12)

                            fieldLabel("Date")
                            TextField("YYYY-MM-DD", text: $date)
                                .font(.system(size: 14))
                                .foregroundColor(AppColor.text)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                        }
                        .padding(16)
                        .background(AppColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))

                        // Total banner
                        HStack {
                            Text("Total").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColor.muted)
                            Spacer()
                            Text(fmt(total)).font(.system(size: 26, weight: .black)).foregroundColor(AppColor.accent)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(AppColor.accent.opacity(0.063))
                        .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.accent.opacity(0.19), lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))

                        // Groups
                        ForEach($editableGroups) { $group in
                            let groupID = group.id

                            GroupCard(
                                group: $group,
                                sourceGroupIDOfActiveDrag: activeDrag?.sourceGroupID,
                                isDropTargeted: activeDrag?.hoverGroupID == group.id,
                                onChangeCategory: { catPickerGroupID = group.id },
                                onDeleteGroup: {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                        if catPickerGroupID == groupID {
                                            catPickerGroupID = nil
                                        }
                                        if activeDrag?.sourceGroupID == groupID || activeDrag?.hoverGroupID == groupID {
                                            activeDrag = nil
                                        }
                                        editableGroups.removeAll { $0.id == groupID }
                                    }
                                },
                                onDragStart: { item, startLocation in
                                    beginItemDrag(item: item, sourceGroupID: group.id, location: startLocation)
                                },
                                onDragMove: { location in
                                    updateItemDrag(location: location)
                                },
                                onDragEnd: { location in
                                    finishItemDrag(location: location)
                                }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity.combined(with: .scale(scale: 0.94))
                                )
                            )
                        }

                        // Add category
                        Button {
                            let newGroup = EditableGroup(category: "Other", items: [EditableItem(name: "", price: 0)])
                            editableGroups.append(newGroup)
                            catPickerGroupID = newGroup.id
                        } label: {
                            HStack(spacing: 6) {
                                Text("+").font(.system(size: 18, weight: .bold))
                                Text("Add Category")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.accent)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(AppColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.accent.opacity(0.31), lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
                .scrollDisabled(activeDrag != nil)
                .onPreferenceChange(GroupCardFramePreferenceKey.self) { frames in
                    groupFrames = frames
                    if let drag = activeDrag {
                        updateItemDrag(location: drag.location)
                    }
                }
            }
            .background(AppColor.bg.ignoresSafeArea())

            if let activeDrag {
                ItemDragPreview(item: activeDrag.previewItem)
                    .position(x: activeDrag.location.x, y: activeDrag.location.y)
                    .allowsHitTesting(false)
                    .zIndex(5)
            }

            // Discard confirmation
            if showDiscardConfirm {
                ConfirmDialog(
                    title: "Discard receipt?",
                    message: "All changes will be lost and this receipt won't be saved.",
                    confirmLabel: "Discard",
                    confirmRole: .destructive,
                    onConfirm: onDiscard,
                    onCancel: { showDiscardConfirm = false }
                )
            }

            // Category picker sheet
            if let pickerID = catPickerGroupID {
                categoryPicker(forID: pickerID)
            }
        }
        .coordinateSpace(name: receiptConfirmDragSpace)
    }

    private func handleConfirm() {
        guard hasAnyItems else { return }

        let out = editableGroups.filter { !$0.items.isEmpty }.map { g in
            ReceiptGroup(
                merchant: merchant,
                date: date,
                currency: groups.first?.currency ?? "USD",
                notes: groups.first?.notes ?? "",
                category: g.category,
                items: g.items.map { i in
                    ReceiptGroup.RawItem(name: i.name, quantity: Double(i.quantity), price: FlexDouble(Double(i.price) ?? 0))
                },
                total: g.total
            )
        }
        onConfirm(out)
    }

    private func beginItemDrag(item: EditableItem, sourceGroupID: UUID, location: CGPoint) {
        guard activeDrag == nil else { return }
        Haptics.light()
        activeDrag = ItemDragSession(
            itemID: item.id,
            sourceGroupID: sourceGroupID,
            previewItem: item,
            location: location,
            hoverGroupID: targetGroupID(for: location, sourceGroupID: sourceGroupID)
        )
    }

    private func updateItemDrag(location: CGPoint) {
        guard var activeDrag else { return }
        activeDrag.location = location
        activeDrag.hoverGroupID = targetGroupID(for: location, sourceGroupID: activeDrag.sourceGroupID)
        self.activeDrag = activeDrag
    }

    private func finishItemDrag(location: CGPoint) {
        guard let activeDrag else { return }
        let targetGroupID = targetGroupID(for: location, sourceGroupID: activeDrag.sourceGroupID)

        defer { self.activeDrag = nil }

        guard let targetGroupID else { return }

        if moveItem(activeDrag.itemID, to: targetGroupID) {
            Haptics.light()
        }
    }

    private func targetGroupID(for location: CGPoint, sourceGroupID: UUID) -> UUID? {
        groupFrames.first { groupID, frame in
            groupID != sourceGroupID && frame.contains(location)
        }?.key
    }

    @discardableResult
    private func moveItem(_ itemID: UUID, to targetGroupID: UUID) -> Bool {
        guard let sourceGroupIndex = editableGroups.firstIndex(where: { group in
            group.items.contains(where: { $0.id == itemID })
        }),
        let sourceItemIndex = editableGroups[sourceGroupIndex].items.firstIndex(where: { $0.id == itemID }),
        editableGroups[sourceGroupIndex].id != targetGroupID
        else {
            return false
        }

        var nextGroups = editableGroups
        let movedItem = nextGroups[sourceGroupIndex].items.remove(at: sourceItemIndex)

        guard let targetGroupIndex = nextGroups.firstIndex(where: { $0.id == targetGroupID }) else {
            return false
        }

        nextGroups[targetGroupIndex].items.append(movedItem)
        nextGroups.removeAll { $0.items.isEmpty }
        editableGroups = nextGroups
        return true
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppColor.muted)
            .kerning(0.5)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func categoryPicker(forID id: UUID) -> some View {
        AppColor.scrimMid.ignoresSafeArea()
            .onTapGesture { catPickerGroupID = nil }

        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text("Select Category")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColor.muted)
                    .textCase(.uppercase)
                    .kerning(0.6)

                let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(allCategoryNames.sorted(), id: \.self) { catName in
                        let ci = categoryInfo(for: catName)
                        let isActive = editableGroups.first { $0.id == id }?.category == catName
                        Button {
                            if let idx = editableGroups.firstIndex(where: { $0.id == id }) {
                                editableGroups[idx].category = catName
                            }
                            catPickerGroupID = nil
                        } label: {
                            VStack(spacing: 4) {
                                Text(ci.emoji).font(.system(size: 20))
                                Text(catName)
                                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
                                    .foregroundColor(isActive ? ci.color : AppColor.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .background(isActive ? ci.color.opacity(0.13) : AppColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(isActive ? ci.color : AppColor.border, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 16)
            .background(AppColor.surface)
            .clipShape(RoundedCornerShape(radius: Radii.xxl, corners: [.topLeft, .topRight]))
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom))
        .zIndex(10)
    }
}

private struct ItemDragSession {
    let itemID: UUID
    let sourceGroupID: UUID
    let previewItem: EditableItem
    var location: CGPoint
    var hoverGroupID: UUID?
}

private struct GroupCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Group card

private struct GroupCard: View {
    @Binding var group: EditableGroup
    var sourceGroupIDOfActiveDrag: UUID?
    var isDropTargeted: Bool
    var onChangeCategory: () -> Void
    var onDeleteGroup: () -> Void
    var onDragStart: (EditableItem, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint) -> Void

    @State private var isDeleteArmed = false
    @State private var deleteResetTask: Task<Void, Never>? = nil

    private var ci: CategoryInfo { categoryInfo(for: group.category) }
    private var isDropCandidate: Bool {
        sourceGroupIDOfActiveDrag != nil && sourceGroupIDOfActiveDrag != group.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            HStack(spacing: 10) {
                Button(action: onChangeCategory) {
                    HStack(spacing: 10) {
                        Text(ci.emoji)
                            .font(.system(size: 17))
                            .frame(width: 32, height: 32)
                            .background(ci.color.opacity(0.144))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(group.category)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ci.color)
                        Spacer()
                        Text(fmt(group.total))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ci.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Button(action: onChangeCategory) {
                        Text("change")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ci.color)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(ci.color.opacity(0.125))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ci.color.opacity(0.25), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if isDeleteArmed {
                            confirmDelete()
                        } else {
                            armDelete()
                        }
                    } label: {
                        HStack(spacing: isDeleteArmed ? 4 : 0) {
                            if isDeleteArmed {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10, weight: .bold))

                                Text("Delete")
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .foregroundColor(isDeleteArmed ? AppColor.onAccent : AppColor.danger)
                        .frame(width: isDeleteArmed ? 76 : 28, height: 24)
                        .background(isDeleteArmed ? AppColor.danger : AppColor.dangerSoftFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isDeleteArmed ? AppColor.danger : AppColor.dangerSoftBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDeleteArmed)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(ci.color.opacity(0.083))

            // Items
            VStack(spacing: 0) {
                ForEach($group.items) { $item in
                    let itemID = item.id
                    let dragPreviewItem = item

                    VStack(spacing: 0) {
                        ItemRow(
                            item: $item,
                            dragPreviewItem: dragPreviewItem,
                            onDragStart: onDragStart,
                            onDragMove: onDragMove,
                            onDragEnd: onDragEnd,
                            onDelete: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                    group.items.removeAll { $0.id == itemID }
                                }
                            }
                        )

                        if itemID != group.items.last?.id {
                            Divider().background(AppColor.border).padding(.horizontal, 14)
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .trailing))
                        )
                    )
                }
            }
            .padding(.horizontal, 0)

            // Add item
            Button {
                group.items.append(EditableItem(name: "", price: 0))
            } label: {
                HStack(spacing: 4) {
                    Text("+").font(.system(size: 16, weight: .bold))
                    Text("Add item")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColor.accent)
                .frame(maxWidth: .infinity)
                .padding(10)
            }
            .buttonStyle(.plain)
            .overlay(Divider().background(AppColor.border), alignment: .top)
        }
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.lg)
                .stroke(isDropTargeted ? ci.color : AppColor.border, lineWidth: isDropTargeted ? 2 : 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .background(isDropTargeted ? ci.color.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .overlay {
            if isDropCandidate {
                CategoryDropOverlay(
                    categoryName: group.category,
                    color: ci.color,
                    isTargeted: isDropTargeted
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radii.lg))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: GroupCardFramePreferenceKey.self, value: [group.id: proxy.frame(in: .named(receiptConfirmDragSpace))])
            }
        )
        .onDisappear {
            deleteResetTask?.cancel()
            deleteResetTask = nil
        }
    }

    private func armDelete() {
        deleteResetTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            isDeleteArmed = true
        }

        deleteResetTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isDeleteArmed = false
                }
                deleteResetTask = nil
            }
        }
    }

    private func confirmDelete() {
        deleteResetTask?.cancel()
        deleteResetTask = nil

        withAnimation(.easeInOut(duration: 0.16)) {
            isDeleteArmed = false
        }
        onDeleteGroup()
    }
}

// MARK: - Item row

private struct ItemRow: View {
    @Binding var item: EditableItem
    let dragPreviewItem: EditableItem
    var onDragStart: (EditableItem, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint) -> Void
    var onDelete: () -> Void

    @State private var didStartDrag = false
    @State private var isDeleteArmed = false
    @State private var deleteResetTask: Task<Void, Never>? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColor.muted)
                    .frame(width: 18)

                TextField("Item name", text: $item.name)
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.text)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 2) {
                    Text("$").font(.system(size: 13)).foregroundColor(AppColor.muted)
                    TextField("0.00", text: $item.price)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColor.text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.22)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(receiptConfirmDragSpace)))
                    .onChanged { value in
                        guard case .second(true, let drag?) = value else { return }

                        if !didStartDrag {
                            didStartDrag = true
                            onDragStart(dragPreviewItem, drag.startLocation)
                        }

                        onDragMove(drag.location)
                    }
                    .onEnded { value in
                        defer { didStartDrag = false }

                        guard case .second(true, let drag?) = value, didStartDrag else { return }
                        onDragEnd(drag.location)
                    }
            )

            Button {
                if isDeleteArmed {
                    confirmDelete()
                } else {
                    armDelete()
                }
            } label: {
                HStack(spacing: isDeleteArmed ? 4 : 0) {
                    if isDeleteArmed {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10, weight: .bold))

                        Text("Delete")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                    } else {
                        Text("×")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(isDeleteArmed ? AppColor.onAccent : AppColor.danger)
                .frame(width: isDeleteArmed ? 76 : 28, height: 26)
                .background(isDeleteArmed ? AppColor.danger : AppColor.dangerSoftFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isDeleteArmed ? AppColor.danger : AppColor.dangerSoftBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDeleteArmed)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onDisappear {
            deleteResetTask?.cancel()
            deleteResetTask = nil
        }
    }

    private func armDelete() {
        deleteResetTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            isDeleteArmed = true
        }

        deleteResetTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isDeleteArmed = false
                }
                deleteResetTask = nil
            }
        }
    }

    private func confirmDelete() {
        deleteResetTask?.cancel()
        deleteResetTask = nil

        withAnimation(.easeInOut(duration: 0.16)) {
            isDeleteArmed = false
        }
        onDelete()
    }
}

private struct ItemDragPreview: View {
    let item: EditableItem

    @State private var previewScale: CGFloat = 0.94
    @State private var previewRotation: Double = -1.2
    @State private var previewYOffset: CGFloat = 6

    private var displayName: String {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled item" : trimmed
    }

    private var displayPrice: String {
        let raw = item.price.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "0.00" : raw
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColor.muted)

            Text(displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("$")
                .font(.system(size: 13))
                .foregroundColor(AppColor.muted)

            Text(displayPrice)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColor.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 320)
        .background(AppColor.surface)
        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
        .scaleEffect(previewScale)
        .rotationEffect(.degrees(previewRotation))
        .offset(y: previewYOffset)
        .shadow(color: AppColor.shadowHeavy.opacity(0.9), radius: 20, x: 0, y: 14)
        .onAppear {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.74)) {
                previewScale = 1.1
                previewYOffset = -4
            }
            withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
                previewRotation = 1.2
            }
        }
    }
}

private struct CategoryDropOverlay: View {
    let categoryName: String
    let color: Color
    let isTargeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radii.lg)
                .fill(AppColor.surface.opacity(isTargeted ? 0.975 : 0.94))

            VStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(color)

                Text(isTargeted ? "Drop to add" : "Add to \(categoryName)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)

                Text("Release anywhere inside this card")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.muted)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radii.lg)
                .strokeBorder(style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 2, dash: [10, 8]))
                .foregroundColor(isTargeted ? color : color.opacity(0.7))
        )
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .allowsHitTesting(false)
    }
}

// MARK: - Confirm dialog

struct ConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = "Confirm"
    var confirmRole: ButtonRole = .destructive
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            AppColor.scrim.ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(AppColor.text)
                    Text(message).font(.system(size: 14)).foregroundColor(AppColor.muted).multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(AppColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.text).fontWeight(.semibold)
                    Button(confirmLabel, role: confirmRole, action: onConfirm)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(AppColor.danger.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.danger.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.danger).fontWeight(.bold)
                }
            }
            .padding(20)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
            .shadow(color: AppColor.shadowHeavy, radius: 20)
        }
        .transition(.opacity)
    }
}
