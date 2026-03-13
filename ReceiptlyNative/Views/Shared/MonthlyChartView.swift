import SwiftUI

struct MonthlyChartView: View {
    let monthlyTotals: [String: Double]

    private var chartData: [(String, Double)] {
        // Sort by month key, take last 6  (mirrors JS: Object.entries(monthlyTotals).sort().slice(-6))
        Array(monthlyTotals.sorted { $0.key < $1.key }.suffix(6))
    }

    private var maxValue: Double {
        max(chartData.map(\.1).max() ?? 0, 1)
    }

    var body: some View {
        if chartData.count < 2 { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Monthly Spending")
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(chartData, id: \.0) { (month, val) in
                        BarColumn(month: month, value: val, maxValue: maxValue)
                    }
                }
                .frame(height: 90)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(AppColor.card)
                .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
            }
            .padding(.bottom, 20)
        }
    }
}

private struct BarColumn: View {
    let month: String
    let value: Double
    let maxValue: Double

    var body: some View {
        let frac = value / maxValue
        return VStack(spacing: 5) {
            Text(fmt(value).split(separator: ".").first.map(String.init) ?? "")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AppColor.muted)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColor.accent.opacity(0.13))
                    .frame(height: 52)
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: [AppColor.accent2, AppColor.accent],
                        startPoint: .bottom, endPoint: .top
                    ))
                    .frame(height: max(4, 52 * frac))
                    .animation(.easeOut(duration: 0.4), value: frac)
            }

            Text(formatMonth(month))
                .font(.system(size: 9))
                .foregroundColor(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
