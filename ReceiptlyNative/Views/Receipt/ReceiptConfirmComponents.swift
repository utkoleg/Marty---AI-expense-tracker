import SwiftUI
import UIKit

struct ArmedDestructiveButton<IdleLabel: View, ArmedLabel: View>: View {
    let idleWidth: CGFloat
    let armedWidth: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var idleForeground: Color = AppColor.danger
    var idleBackground: Color = AppColor.dangerSoftFill
    var idleBorder: Color = AppColor.dangerSoftBorder
    var armedForeground: Color = AppColor.onAccent
    var armedBackground: Color = AppColor.danger
    var armedBorder: Color = AppColor.danger
    var onConfirm: () -> Void
    let idleLabel: () -> IdleLabel
    let armedLabel: () -> ArmedLabel

    @State private var isArmed = false
    @State private var resetTask: Task<Void, Never>? = nil

    init(
        idleWidth: CGFloat,
        armedWidth: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        idleForeground: Color = AppColor.danger,
        idleBackground: Color = AppColor.dangerSoftFill,
        idleBorder: Color = AppColor.dangerSoftBorder,
        armedForeground: Color = AppColor.onAccent,
        armedBackground: Color = AppColor.danger,
        armedBorder: Color = AppColor.danger,
        onConfirm: @escaping () -> Void,
        @ViewBuilder idleLabel: @escaping () -> IdleLabel,
        @ViewBuilder armedLabel: @escaping () -> ArmedLabel
    ) {
        self.idleWidth = idleWidth
        self.armedWidth = armedWidth
        self.height = height
        self.cornerRadius = cornerRadius
        self.idleForeground = idleForeground
        self.idleBackground = idleBackground
        self.idleBorder = idleBorder
        self.armedForeground = armedForeground
        self.armedBackground = armedBackground
        self.armedBorder = armedBorder
        self.onConfirm = onConfirm
        self.idleLabel = idleLabel
        self.armedLabel = armedLabel
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: isArmed ? 4 : 0) {
                if isArmed {
                    armedLabel()
                } else {
                    idleLabel()
                }
            }
            .foregroundColor(isArmed ? armedForeground : idleForeground)
            .frame(width: isArmed ? armedWidth : idleWidth, height: height)
            .background(isArmed ? armedBackground : idleBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isArmed ? armedBorder : idleBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isArmed)
        .onDisappear {
            resetTask?.cancel()
            resetTask = nil
        }
    }

    private func handleTap() {
        if isArmed {
            confirm()
        } else {
            arm()
        }
    }

    private func arm() {
        resetTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            isArmed = true
        }

        resetTask = Task {
            try? await Task.sleep(nanoseconds: UIActionDelay.armedDestructiveResetNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isArmed = false
                }
                resetTask = nil
            }
        }
    }

    private func confirm() {
        resetTask?.cancel()
        resetTask = nil

        withAnimation(.easeInOut(duration: 0.16)) {
            isArmed = false
        }
        onConfirm()
    }
}

struct ReceiptConfirmGroupCard: View {
    @Binding var group: EditableGroup
    let currencyCode: String
    var sourceGroupIDOfActiveDrag: UUID?
    var isDropTargeted: Bool
    var onChangeCategory: () -> Void
    var onDeleteGroup: () -> Void
    var onDragStart: (EditableItem, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint) -> Void
    var showValidationErrors: Bool

    private var categoryInfoValue: CategoryInfo { categoryInfo(for: group.category) }
    private var isDropCandidate: Bool {
        sourceGroupIDOfActiveDrag != nil && sourceGroupIDOfActiveDrag != group.id
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onChangeCategory) {
                    HStack(spacing: 12) {
                        CategoryIconView(info: categoryInfoValue, size: 34, cornerRadius: 11, weight: .medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Category", "Категория"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColor.muted)
                                .textCase(.uppercase)
                                .kerning(0.4)

                            Text(localizedCategoryName(group.category))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(categoryInfoValue.color)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColor.muted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surface.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.md)
                            .stroke(categoryInfoValue.color.opacity(0.22), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Text(fmt(group.total, currencyCode: currencyCode))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(categoryInfoValue.color)

                    ArmedDestructiveButton(
                        idleWidth: 28,
                        armedWidth: 76,
                        height: 24,
                        cornerRadius: 6,
                        onConfirm: onDeleteGroup
                    ) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                    } armedLabel: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(loc("Delete", "Удалить"))
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(categoryInfoValue.color.opacity(0.083))

            VStack(spacing: 0) {
                ForEach($group.items) { $item in
                    let itemID = item.id
                    let dragPreviewItem = item

                    VStack(spacing: 0) {
                        ReceiptConfirmItemRow(
                            item: $item,
                            currencyCode: currencyCode,
                            dragPreviewItem: dragPreviewItem,
                            onDragStart: onDragStart,
                            onDragMove: onDragMove,
                            onDragEnd: onDragEnd,
                            showValidationErrors: showValidationErrors,
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
                            removal: .opacity
                                .combined(with: .scale(scale: 0.9))
                                .combined(with: .move(edge: .trailing))
                        )
                    )
                }
            }

            Button {
                group.items.append(EditableItem(name: "", price: 0))
            } label: {
                HStack(spacing: 4) {
                    Text("+").font(.system(size: 16, weight: .bold))
                    Text(loc("Add item", "Добавить позицию"))
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
                .stroke(
                    isDropTargeted ? categoryInfoValue.color : AppColor.border,
                    lineWidth: isDropTargeted ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .background(isDropTargeted ? categoryInfoValue.color.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .overlay {
            if isDropCandidate {
                ReceiptCategoryDropOverlay(
                    categoryName: group.category,
                    color: categoryInfoValue.color,
                    isTargeted: isDropTargeted
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radii.lg))
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GroupCardFramePreferenceKey.self,
                    value: [group.id: proxy.frame(in: .named(receiptConfirmDragSpace))]
                )
            }
        )
    }
}

struct ReceiptConfirmItemRow: View {
    @Binding var item: EditableItem
    let currencyCode: String
    let dragPreviewItem: EditableItem
    var onDragStart: (EditableItem, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint) -> Void
    var showValidationErrors: Bool
    var onDelete: () -> Void

    @State private var didStartDrag = false

    private var nameValidationMessage: String? {
        ReceiptDraftValidation.itemNameMessage(for: item)
    }

    private var priceValidationMessage: String? {
        ReceiptDraftValidation.itemPriceMessage(for: item)
    }

    private var showsValidationMessages: Bool {
        showValidationErrors && (nameValidationMessage != nil || priceValidationMessage != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showsValidationMessages ? 6 : 0) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.muted)
                        .frame(width: 18)

                    ReceiptInlineEditingTextField(
                        placeholder: loc("Item name", "Название"),
                        text: $item.name,
                        font: .systemFont(ofSize: 14),
                        textColor: UIColor(AppColor.text),
                        autocorrectionType: .yes
                    )
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 2) {
                        Text(currencySymbol(for: currencyCode))
                            .font(.system(size: 13))
                            .foregroundColor(AppColor.muted)

                        ReceiptInlineEditingTextField(
                            placeholder: "0.00",
                            text: $item.price,
                            font: .systemFont(ofSize: 14, weight: .bold),
                            textColor: UIColor(AppColor.text),
                            keyboardType: .decimalPad,
                            textAlignment: .right,
                            autocorrectionType: .no
                        )
                        .frame(width: 64)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(
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

                ArmedDestructiveButton(
                    idleWidth: 28,
                    armedWidth: 76,
                    height: 26,
                    cornerRadius: 7,
                    onConfirm: onDelete
                ) {
                    Text("×")
                        .font(.system(size: 16, weight: .bold))
                } armedLabel: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(loc("Delete", "Удалить"))
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
            }

            if showsValidationMessages {
                HStack(alignment: .top, spacing: 8) {
                    Color.clear.frame(width: 18)

                    Text(nameValidationMessage ?? " ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(nameValidationMessage == nil ? 0 : 1)

                    Text(priceValidationMessage ?? " ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColor.danger)
                        .frame(width: 64, alignment: .trailing)
                        .opacity(priceValidationMessage == nil ? 0 : 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct ReceiptInlineEditingTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var font: UIFont
    var textColor: UIColor
    var keyboardType: UIKeyboardType = .default
    var textAlignment: NSTextAlignment = .left
    var autocorrectionType: UITextAutocorrectionType = .default

    func makeUIView(context: Context) -> NonSelectingTextField {
        let textField = NonSelectingTextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator
        textField.font = font
        textField.textColor = textColor
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.autocorrectionType = autocorrectionType
        textField.autocapitalizationType = .sentences
        textField.returnKeyType = .done
        textField.placeholder = placeholder
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: NonSelectingTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.font = font
        uiView.textColor = textColor
        uiView.keyboardType = keyboardType
        uiView.textAlignment = textAlignment
        uiView.autocorrectionType = autocorrectionType
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func editingChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

final class NonSelectingTextField: UITextField {
    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer is UILongPressGestureRecognizer {
            gestureRecognizer.isEnabled = false
        }
        super.addGestureRecognizer(gestureRecognizer)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}

struct ReceiptItemDragPreview: View {
    let item: EditableItem
    let currencyCode: String

    @State private var previewScale: CGFloat = 0.94
    @State private var previewRotation: Double = -1.2
    @State private var previewYOffset: CGFloat = 6

    private var displayName: String {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? loc("Untitled item", "Без названия") : trimmed
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

            Text(currencySymbol(for: currencyCode))
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

struct ReceiptCategoryDropOverlay: View {
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

                Text(
                    isTargeted
                        ? loc("Drop to add", "Отпусти, чтобы добавить")
                        : loc("Add to \(localizedCategoryName(categoryName))", "Добавить в \(localizedCategoryName(categoryName))")
                )
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)

                Text(loc("Release anywhere inside this card", "Отпусти в любой части этой карточки"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.muted)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radii.lg)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 2, dash: [10, 8])
                )
                .foregroundColor(isTargeted ? color : color.opacity(0.7))
        )
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
        .allowsHitTesting(false)
    }
}

struct ReceiptConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = loc("Confirm", "Подтвердить")
    var confirmRole: ButtonRole = .destructive
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            AppColor.scrim.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColor.text)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button(loc("Cancel", "Отмена"), action: onCancel)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radii.md)
                                .stroke(AppColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.text)
                        .fontWeight(.semibold)

                    Button(confirmLabel, role: confirmRole, action: onConfirm)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppColor.danger.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radii.md)
                                .stroke(AppColor.danger.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .foregroundColor(AppColor.danger)
                        .fontWeight(.bold)
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
