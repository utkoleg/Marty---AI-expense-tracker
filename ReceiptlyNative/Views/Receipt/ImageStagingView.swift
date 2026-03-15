import SwiftUI

struct ImageStagingView: View {
    let images: [StagedImage]
    var onAddMore: () -> Void
    var onRemove: (Int) -> Void
    var onAnalyze: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizedPhotosReadyText(images.count))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.text)

                        Text(loc(
                            "Review the images below, remove any extras, and then analyze the receipt.",
                            "Проверь фото ниже, удали лишние и затем запусти анализ чека."
                        ))
                            .font(.subheadline)
                            .foregroundStyle(AppColor.muted)
                    }

                    Button(action: {
                        Haptics.light()
                        onAddMore()
                    }) {
                        Label(loc("Add More Photos", "Добавить еще фото"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(AppColor.accent)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image.uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 128, height: 164)
                                        .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))

                                    Button {
                                        Haptics.light()
                                        onRemove(index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, Color.black.opacity(0.72))
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 12)
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .appBackground()
            .navigationTitle(loc("Ready to Scan", "Готово к сканированию"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Cancel", "Отмена"), action: onCancel)
                        .foregroundStyle(AppColor.danger)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()

                    Button(action: {
                        Haptics.heavy()
                        onAnalyze()
                    }) {
                        Label(
                            loc(
                                images.count > 1 ? "Analyze Receipts" : "Analyze Receipt",
                                images.count > 1 ? "Анализировать чеки" : "Анализировать чек"
                            ),
                            systemImage: "sparkles"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.bar)
                }
            }
        }
    }
}
