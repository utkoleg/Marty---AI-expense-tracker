import SwiftUI

struct ImageStagingView: View {
    let images: [StagedImage]
    var onAddMore: () -> Void
    var onRemove: (Int) -> Void
    var onAnalyze: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { Haptics.light(); onCancel() }) { Text("Cancel") }
                    .foregroundColor(AppColor.danger)
                Spacer()
                Text("\(images.count) Image\(images.count == 1 ? "" : "s") Ready")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColor.text)
                Spacer()
                Button(action: { Haptics.light(); onAddMore() }) {
                    Text("+ Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(AppColor.border)

            // Image scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { i, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img.uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: Radii.md))

                            Button {
                                Haptics.light(); onRemove(i)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppColor.onAccent)
                                    .background(Circle().fill(AppColor.scrimStrong))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Divider().background(AppColor.border)

            // Analyze button
            Button(action: { Haptics.heavy(); onAnalyze() }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Analyze Receipt\(images.count > 1 ? "s" : "")")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColor.onAccent)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(LinearGradient(
                    colors: [AppColor.accent, AppColor.accent2],
                    startPoint: .leading, endPoint: .trailing
                ))
                .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
        .background(AppColor.surface)
    }
}
