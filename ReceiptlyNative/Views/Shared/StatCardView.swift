import SwiftUI

struct StatCardView: View {
    let label: String
    let value: String
    var sub: String = ""
    var color: Color = AppColor.accent
    var symbolName: String? = nil
    var fill: Color = AppColor.tertiarySurface

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let symbolName {
                SymbolBadge(systemName: symbolName, color: color, size: 34, cornerRadius: 12, weight: .medium)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.muted)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            if !sub.isEmpty {
                Text(sub)
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(16)
        .cardStyle(fill: fill, stroke: AppColor.hairline)
    }
}
