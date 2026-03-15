import UIKit
import XCTest
@testable import ReceiptlyNative

final class UserProfileImageStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directoryURL, FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    func testSaveAndLoadRoundTripReturnsImage() throws {
        let store = UserProfileImageStore(directoryURL: directoryURL)
        let userID = UUID()
        let image = makeImage(color: .systemBlue)

        try store.save(image, for: userID)

        let loadedImage = store.image(for: userID)

        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(loadedImage?.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(loadedImage?.cgImage?.height, image.cgImage?.height)
    }

    func testRemoveImageDeletesStoredFile() throws {
        let store = UserProfileImageStore(directoryURL: directoryURL)
        let userID = UUID()

        try store.save(makeImage(color: .systemGreen), for: userID)
        try store.removeImage(for: userID)

        XCTAssertNil(store.image(for: userID))
    }

    private func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 48))
        }
    }
}
