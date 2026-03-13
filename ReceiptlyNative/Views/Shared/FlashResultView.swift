import SwiftUI

struct FlashResultView: View {
    let expense: Expense?

    var body: some View {
        if let exp = expense {
            let cat = categoryInfo(for: exp.category)
            HStack(spacing: 10) {
                Text(cat.emoji)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved — \(exp.merchant.isEmpty ? exp.category : exp.merchant)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColor.text)
                        .lineLimit(1)
                    Text(fmt(exp.total))
                        .font(.system(size: 11))
                        .foregroundColor(AppColor.muted)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColor.success)
            }
            .padding(14)
            .background(AppColor.surface)
            .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(AppColor.success.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Radii.md))
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .padding(.bottom, 8)
        }
    }
}
