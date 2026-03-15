import SwiftUI

let receiptConfirmDragSpace = "receiptConfirmDragSpace"

struct ReceiptConfirmView: View {
    let groups: [ReceiptGroup]
    var onConfirm: ([ReceiptGroup]) -> Void
    var onDiscard: () -> Void

    @State private var draft: ReceiptDraft
    @State private var catPickerGroupID: UUID? = nil
    @State private var isDatePickerPresented = false
    @State private var showDiscardConfirm = false
    @State private var activeDrag: ItemDragSession? = nil
    @State private var groupFrames: [UUID: CGRect] = [:]
    @State private var showValidationErrors = false

    private var categoryPickerBinding: Binding<Bool> {
        Binding(
            get: { catPickerGroupID != nil },
            set: { isPresented in
                if !isPresented {
                    catPickerGroupID = nil
                }
            }
        )
    }

    init(groups: [ReceiptGroup], onConfirm: @escaping ([ReceiptGroup]) -> Void, onDiscard: @escaping () -> Void) {
        self.groups = groups
        self.onConfirm = onConfirm
        self.onDiscard = onDiscard
        _draft = State(initialValue: ReceiptDraft(groups: groups))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                content
            }
            .background(AppColor.bg.ignoresSafeArea())

            if let activeDrag {
                ReceiptItemDragPreview(
                    item: activeDrag.previewItem,
                    currencyCode: draft.currency ?? currentBaseCurrencyCode()
                )
                    .position(x: activeDrag.location.x, y: activeDrag.location.y)
                    .allowsHitTesting(false)
                    .zIndex(5)
            }

            if showDiscardConfirm {
                ReceiptConfirmDialog(
                    title: loc("Discard receipt?", "Отменить чек?"),
                    message: loc(
                        "All changes will be lost and this receipt won't be saved.",
                        "Все изменения будут потеряны, и этот чек не сохранится."
                    ),
                    confirmLabel: loc("Discard", "Отменить"),
                    confirmRole: .destructive,
                    onConfirm: onDiscard,
                    onCancel: { showDiscardConfirm = false }
                )
            }
        }
        .coordinateSpace(name: receiptConfirmDragSpace)
        .sheet(isPresented: categoryPickerBinding) {
            categoryPickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            receiptDatePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button(loc("Discard", "Отменить")) { showDiscardConfirm = true }
                .foregroundStyle(AppColor.danger)

            Spacer()

            VStack(spacing: 1) {
                Text(loc("Review Receipt", "Проверь чек"))
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                Text(loc("Tap to edit or drag items between categories", "Нажимай для редактирования или перетаскивай позиции между категориями"))
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }

            Spacer()

            Button(loc("Save", "Сохранить")) { handleConfirm() }
                .buttonStyle(.borderedProminent)
                .tint(draft.hasAnyItems ? AppColor.accent : AppColor.muted.opacity(0.45))
                .disabled(!draft.hasAnyItems)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(Divider().background(AppColor.hairline), alignment: .bottom)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                merchantDateCard
                totalBanner
                editableGroupsSection
                addCategoryButton
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

    private var merchantDateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel(loc("Merchant", "Магазин"))
            TextField(loc("Merchant name", "Название магазина"), text: $draft.merchant)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.text)
                .padding(.bottom, 6)
                .overlay(
                    Divider().background(
                        showValidationErrors && draft.merchantValidationMessage != nil
                            ? AppColor.danger.opacity(0.45)
                            : AppColor.border
                    ),
                    alignment: .bottom
                )

            if showValidationErrors, let merchantValidationMessage = draft.merchantValidationMessage {
                validationMessage(merchantValidationMessage)
                    .padding(.top, 6)
            }

            Spacer().frame(height: 12)

            fieldLabel(loc("Date", "Дата"))
            Button {
                isDatePickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDraftDate)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.text)

                        Text(loc("Tap to change", "Нажми, чтобы изменить"))
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }

                    Spacer()

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.accent)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                        .fill(AppColor.tertiarySurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                        .stroke(AppColor.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showValidationErrors, let dateValidationMessage = draft.dateValidationMessage {
                validationMessage(dateValidationMessage)
                    .padding(.top, 6)
            }

            Spacer().frame(height: 12)

            fieldLabel(loc("Currency", "Валюта"))
            Menu {
                ForEach(BaseCurrencyOption.allCases) { currency in
                    Button(currency.displayName) {
                        draft.currency = currency.rawValue
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currencyDisplayName(draft.currency ?? currentBaseCurrencyCode()))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.text)

                        Text(normalizedCurrencyCode(draft.currency))
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }

                    Spacer()

                    Image(systemName: "dollarsign.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.accent)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                        .fill(AppColor.tertiarySurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                        .stroke(AppColor.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cardStyle(
            fill: AppColor.elevated,
            stroke: showValidationErrors &&
                (draft.merchantValidationMessage != nil || draft.dateValidationMessage != nil)
                ? AppColor.danger.opacity(0.24)
                : AppColor.hairline
        )
    }

    private var totalBanner: some View {
        HStack {
            Text(loc("Total", "Итого"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.muted)
            Spacer()
            Text(fmt(draft.total, currencyCode: draft.currency))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle(fill: AppColor.accentSoft, stroke: AppColor.accent.opacity(0.14))
    }

    private var editableGroupsSection: some View {
        ForEach($draft.groups) { $group in
            let groupID = group.id

            ReceiptConfirmGroupCard(
                group: $group,
                currencyCode: draft.currency ?? currentBaseCurrencyCode(),
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
                        draft.deleteGroup(id: groupID)
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
                },
                showValidationErrors: showValidationErrors
            )
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity.combined(with: .scale(scale: 0.94))
                )
            )
        }
    }

    private var addCategoryButton: some View {
        Button {
            let newGroupID = draft.addGroup()
            catPickerGroupID = newGroupID
        } label: {
            HStack(spacing: 6) {
                Text("+").font(.system(size: 18, weight: .bold))
                Text(loc("Add Category", "Добавить категорию"))
            }
            .font(.headline)
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity)
            .padding(14)
            .cardStyle(fill: AppColor.elevated, stroke: AppColor.accent.opacity(0.22))
        }
        .buttonStyle(.plain)
    }

    private func handleConfirm() {
        guard draft.hasAnyItems else { return }
        showValidationErrors = true
        guard !draft.hasValidationErrors else { return }
        onConfirm(draft.buildReceiptGroups())
    }

    private var draftDateSelection: Binding<Date> {
        Binding(
            get: { receiptEditorDate(from: draft.date) },
            set: { draft.date = receiptEditorStorageDateString(from: $0) }
        )
    }

    private var formattedDraftDate: String {
        receiptEditorDisplayDateString(from: receiptEditorDate(from: draft.date))
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

        if draft.moveItem(activeDrag.itemID, to: targetGroupID) {
            Haptics.light()
        }
    }

    private func targetGroupID(for location: CGPoint, sourceGroupID: UUID) -> UUID? {
        groupFrames.first { groupID, frame in
            groupID != sourceGroupID && frame.contains(location)
        }?.key
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.muted)
            .kerning(0.5)
            .padding(.bottom, 6)
    }

    private func validationMessage(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.danger)
    }

    @ViewBuilder
    private var categoryPickerSheet: some View {
        if let pickerID = catPickerGroupID {
            ReceiptCategorySelectionSheet(
                selectedCategory: draft.selectedCategory(for: pickerID) ?? "Other",
                onSelect: { categoryName in
                    draft.setCategory(categoryName, for: pickerID)
                    catPickerGroupID = nil
                }
            )
        }
    }

    private var receiptDatePickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                DatePicker(
                    loc("Receipt Date", "Дата чека"),
                    selection: draftDateSelection,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 14)

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .navigationTitle(loc("Receipt Date", "Дата чека"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc("Today", "Сегодня")) {
                        draft.date = todayString()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("Done", "Готово")) {
                        isDatePickerPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ItemDragSession {
    let itemID: UUID
    let sourceGroupID: UUID
    let previewItem: EditableItem
    var location: CGPoint
    var hoverGroupID: UUID?
}

struct GroupCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private let receiptEditorStorageFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private func receiptEditorDisplayFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
}

private func receiptEditorDate(from raw: String) -> Date {
    let trimmed = sanitizeReceiptDate(raw)
    let parts = trimmed.split(separator: "-")

    guard parts.count == 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let day = Int(parts[2])
    else {
        return Date()
    }

    var components = DateComponents()
    components.calendar = Calendar.current
    components.timeZone = TimeZone.current
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components) ?? Date()
}

private func receiptEditorStorageDateString(from date: Date) -> String {
    receiptEditorStorageFormatter.string(from: date)
}

private func receiptEditorDisplayDateString(from date: Date) -> String {
    receiptEditorDisplayFormatter().string(from: date)
}
