import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    var categoryFilter: String? = nil
    var onClose: () -> Void
    var onDelete: (String) -> Void
    var onEdit: (Expense) -> Void
    var onCategoryPress: ((String) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showFull = false

    private var cat: CategoryInfo { categoryInfo(for: expense.category) }
    private var isMulti: Bool { (expense.groups?.count ?? 0) > 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Backdrop
            AppColor.scrimLight
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Sheet
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(AppColor.border)
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // Header
                sheetHeader
                    .padding(20)
                    .overlay(Divider().background(AppColor.border), alignment: .bottom)

                // Body
                ScrollView {
                    sheetBody.padding(20)
                }
            }
            .background(AppColor.surface)
            .overlay(
                RoundedCornerShape(radius: Radii.xxl, corners: [.topLeft, .topRight])
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .clipShape(RoundedCornerShape(radius: Radii.xxl, corners: [.topLeft, .topRight]))
            .shadow(color: AppColor.shadowMedium, radius: 24, x: 0, y: -2)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.88)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { v in
                        let dy = v.translation.height
                        if dy > 0 { dragOffset = dy - 8 }
                    }
                    .onEnded { v in
                        if dragOffset > 90 { onClose() }
                        else { withAnimation(.spring(response: 0.4)) { dragOffset = 0 } }
                    }
            )
            .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var sheetHeader: some View {
        HStack(spacing: 12) {
            // Category icon(s)
            if isMulti, let groups = expense.groups {
                HStack(spacing: 4) {
                    ForEach(groups, id: \.category) { g in
                        let ci = categoryInfo(for: g.category)
                        Text(ci.emoji)
                            .font(.system(size: 18))
                            .frame(width: 34, height: 34)
                            .background(ci.color.opacity(0.125))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Text(cat.emoji).font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? "(no merchant)" : expense.merchant)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(AppColor.text)
                Text("\(expense.date) · \(isMulti ? "\(expense.groups?.count ?? 0) categories" : expense.category)")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.muted)
            }
            Spacer()
            HStack(spacing: 8) {
                actionButton(icon: "✏️", color: AppColor.accent, background: AppColor.accent.opacity(0.1)) {
                    onEdit(expense)
                }
                actionButton(icon: "🗑", color: AppColor.danger, background: AppColor.danger.opacity(0.1)) {
                    onDelete(expense.id)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.text)
                        .frame(width: 34, height: 34)
                        .background(AppColor.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
                }
            }
        }
    }

    private func actionButton(icon: String, color: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(background)
                .overlay(RoundedRectangle(cornerRadius: Radii.sm).stroke(color.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
        }
    }

    @ViewBuilder
    private var sheetBody: some View {
        // Filtered category view
        if let filter = categoryFilter, !showFull {
            let group = expense.groups?.first { $0.category == filter }
                ?? ExpenseGroup(category: expense.category, items: expense.items, total: expense.total)
            let ci = categoryInfo(for: group.category)

            VStack(alignment: .leading, spacing: 0) {
                // Category total banner
                HStack {
                    Text("\(filter) total").font(.system(size: 13)).foregroundColor(AppColor.muted)
                    Spacer()
                    Text(fmt(group.total)).font(.system(size: 28, weight: .black)).foregroundColor(ci.color)
                }
                .padding(14)
                .background(AppColor.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)

                // Category pill
                categoryPill(name: filter, ci: ci, total: nil)
                    .padding(.bottom, 6)

                // Items
                itemList(group.items)

                // "Show whole receipt" button
                Button { withAnimation { showFull = true } } label: {
                    Text("Show whole receipt ›")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.border, lineWidth: 1))
                }
                .padding(.top, 20)
            }
        } else {
            // Full receipt view
            VStack(alignment: .leading, spacing: 0) {
                // Total paid banner
                HStack {
                    Text("Total Paid").font(.system(size: 13)).foregroundColor(AppColor.muted)
                    Spacer()
                    Text(fmt(expense.total)).font(.system(size: 28, weight: .black)).foregroundColor(AppColor.accent)
                }
                .padding(14)
                .background(AppColor.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)

                if !expense.notes.isEmpty {
                    Text(expense.notes)
                        .font(.system(size: 13))
                        .foregroundColor(AppColor.muted)
                        .padding(14)
                        .background(AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .padding(.bottom, 16)
                }

                if expense.items.isEmpty {
                    Text("No line items extracted. Try a clearer image.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColor.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if isMulti, let groups = expense.groups {
                    ForEach(groups, id: \.category) { g in
                        let ci = categoryInfo(for: g.category)
                        VStack(alignment: .leading, spacing: 6) {
                            categoryPill(name: g.category, ci: ci, total: g.total)
                            itemList(g.items)
                        }
                        .padding(.bottom, 20)
                    }
                    // Grand total line
                    HStack {
                        Text("Total").font(.system(size: 17, weight: .black)).foregroundColor(AppColor.muted)
                        Spacer()
                        Text(fmt(expense.total)).font(.system(size: 17, weight: .black)).foregroundColor(AppColor.accent)
                    }
                    .padding(.top, 8)
                    .overlay(Divider().background(AppColor.accent), alignment: .top)
                } else {
                    categoryPill(name: expense.category, ci: cat, total: expense.total)
                        .padding(.bottom, 6)
                    itemList(expense.items)
                    HStack {
                        Text("Total").font(.system(size: 17, weight: .black)).foregroundColor(AppColor.muted)
                        Spacer()
                        Text(fmt(expense.total)).font(.system(size: 17, weight: .black)).foregroundColor(AppColor.accent)
                    }
                    .padding(.top, 16)
                    .overlay(Divider().background(AppColor.accent), alignment: .top)
                }
            }
        }
    }

    private func categoryPill(name: String, ci: CategoryInfo, total: Double?) -> some View {
        Button {
            onCategoryPress?(name)
        } label: {
            HStack(spacing: 8) {
                Text(ci.emoji).font(.system(size: 16))
                Text(name).font(.system(size: 13, weight: .bold)).foregroundColor(ci.color)
                if let t = total {
                    Spacer()
                    Text(fmt(t)).font(.system(size: 13, weight: .bold)).foregroundColor(ci.color)
                } else {
                    Spacer()
                }
                if onCategoryPress != nil {
                    Text("›").font(.system(size: 11)).foregroundColor(ci.color.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ci.color.opacity(0.078))
            .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(ci.color.opacity(0.16), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Radii.md))
        }
        .disabled(onCategoryPress == nil)
        .buttonStyle(.plain)
    }

    private func itemList(_ items: [ExpenseItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack {
                    Text(item.name.isEmpty ? "(unnamed)" : item.name)
                        .font(.system(size: 15))
                        .foregroundColor(AppColor.text)
                    Spacer()
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColor.muted)
                            .padding(.trailing, 10)
                    }
                    Text(fmt(item.price))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColor.text)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                if i < items.count - 1 {
                    Divider().background(AppColor.border)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(AppColor.card)
        .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
    }
}

// MARK: - Rounded corner helper

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
