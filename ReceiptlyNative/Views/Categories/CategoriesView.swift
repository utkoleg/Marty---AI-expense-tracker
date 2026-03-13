import SwiftUI

struct CategoriesView: View {
    let stats: Stats
    var onCategoryPress: (String) -> Void
    var onRefresh: () async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                SectionLabel("\(stats.usedCats.count) Active Categories")

                if stats.usedCats.isEmpty {
                    Text("No categories yet.\nScan a receipt first!")
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(stats.usedCats, id: \.self) { cat in
                            CategoryRow(
                                cat: cat,
                                total: stats.catTotals[cat] ?? 0,
                                count: stats.catCounts[cat] ?? 0,
                                totalSpent: stats.totalSpent,
                                onPress: { onCategoryPress(cat) }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .refreshable { await onRefresh() }
        .background(Color.clear)
    }
}

private struct CategoryRow: View {
    let cat: String
    let total: Double
    let count: Int
    let totalSpent: Double
    let onPress: () -> Void

    private var ci: CategoryInfo { categoryInfo(for: cat) }
    private var pct: Double { totalSpent > 0 ? (total / totalSpent) * 100 : 0 }

    var body: some View {
        Button(action: onPress) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Text(ci.emoji)
                        .font(.system(size: 26))
                        .frame(width: 48, height: 48)
                        .background(ci.color.opacity(0.094))
                        .clipShape(RoundedRectangle(cornerRadius: 15))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(cat)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColor.text)
                        Text("\(count) expense\(count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(AppColor.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(fmt(total))
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(ci.color)
                        Text(String(format: "%.0f%%", pct))
                            .font(.system(size: 11))
                            .foregroundColor(AppColor.muted)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999)
                            .fill(AppColor.surface)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 999)
                            .fill(ci.color)
                            .frame(width: geo.size.width * pct / 100, height: 5)
                            .animation(.easeOut(duration: 0.4), value: pct)
                    }
                }
                .frame(height: 5)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
