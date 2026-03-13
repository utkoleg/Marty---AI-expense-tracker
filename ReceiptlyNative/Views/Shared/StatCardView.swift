import SwiftUI

struct StatCardView: View {
    let label: String
    let value: String
    var sub: String = ""
    var color: Color = AppColor.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColor.muted)
                .textCase(.uppercase)
                .kerning(0.4)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(AppColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}
