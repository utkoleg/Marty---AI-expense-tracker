import SwiftUI
import PhotosUI

// MARK: - Upload source action sheet

struct UploadSheetView: View {
    var onCamera: () -> Void
    var onLibrary: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule().fill(AppColor.border).frame(width: 36, height: 4)
                .padding(.top, 14).padding(.bottom, 16)

            Text("Add Receipt")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppColor.text)
                .padding(.bottom, 20)

            UploadOption(emoji: "📷", title: "Take Photo", subtitle: "Use camera", action: onCamera)
            Divider().background(AppColor.border)
            UploadOption(emoji: "🖼️", title: "Photo Library", subtitle: "Choose existing photo", action: onLibrary)

            Button(action: { Haptics.light(); onClose() }) { Text("Cancel") }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.muted)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.surface)
    }
}

private struct UploadOption: View {
    let emoji: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 26))
                    .frame(width: 48, height: 48)
                    .background(AppColor.accent.opacity(0.094))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppColor.text)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(AppColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColor.muted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PHPickerViewController wrapper

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                        if let img = obj as? UIImage {
                            DispatchQueue.main.async { self.onPick(img) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UIImagePickerController wrapper (Camera)

struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}
