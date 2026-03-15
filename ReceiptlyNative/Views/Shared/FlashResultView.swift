import SwiftUI

struct FlashResultView: View {
    let expense: Expense
    let isVisible: Bool
    var onPress: () -> Void

    var body: some View {
        let category = categoryInfo(for: expense.category)

        Button(action: onPress) {
            HStack(spacing: 12) {
                SymbolBadge(systemName: "checkmark", color: AppColor.success, size: 36, cornerRadius: 12, weight: .bold)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("Receipt saved", "Чек сохранен"))
                        .font(.headline)
                        .foregroundStyle(AppColor.text)

                    Text(expense.merchant.isEmpty ? localizedCategoryName(expense.category) : expense.merchant)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(category.color)

                    Text(loc("Tap to view the full receipt", "Нажми, чтобы открыть весь чек"))
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.displayAmountText(for: expense.total))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.success)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.success.opacity(0.08), in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .stroke(AppColor.success.opacity(0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.97, anchor: .top)
        .offset(y: isVisible ? 0 : -10)
    }
}
