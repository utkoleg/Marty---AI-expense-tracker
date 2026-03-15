import Foundation
import UIKit

struct UserProfileImageStore {
    static let shared = UserProfileImageStore()

    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.directoryURL = documentsURL.appendingPathComponent("ProfileImages", isDirectory: true)
        }
    }

    func image(for userID: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(for: userID)) else {
            return nil
        }

        return UIImage(data: data)
    }

    func save(_ image: UIImage, for userID: UUID) throws {
        try ensureDirectory()

        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw UserProfileImageStoreError.encodingFailed
        }

        try data.write(to: fileURL(for: userID), options: .atomic)
    }

    func removeImage(for userID: UUID) throws {
        let url = fileURL(for: userID)

        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func ensureDirectory() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func fileURL(for userID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(userID.uuidString.lowercased()).jpg")
    }
}

enum UserProfileImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        loc(
            "Couldn't prepare the profile image for saving.",
            "Не удалось подготовить фото профиля к сохранению."
        )
    }
}
