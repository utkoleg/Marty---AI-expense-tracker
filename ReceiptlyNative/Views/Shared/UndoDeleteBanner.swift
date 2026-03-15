import SwiftUI

struct UndoDeleteBanner: View {
    let expense: Expense
    let isVisible: Bool
    var onUndo: () -> Void

    private var title: String {
        expense.merchant.isEmpty ? localizedCategoryName(expense.category) : expense.merchant
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColor.danger)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColor.dangerSoftFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColor.dangerSoftBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(loc("Receipt deleted", "Чек удален"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.text)

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(loc("Undo", "Отменить"), action: onUndo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColor.accentSoft, in: Capsule())
        }
        .padding(14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                .stroke(AppColor.hairline, lineWidth: 1)
        )
        .shadow(color: AppColor.shadowHeavy.opacity(0.16), radius: 18, x: 0, y: 10)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.98, anchor: .bottom)
        .offset(y: isVisible ? 0 : 18)
        .allowsHitTesting(isVisible)
    }
}
