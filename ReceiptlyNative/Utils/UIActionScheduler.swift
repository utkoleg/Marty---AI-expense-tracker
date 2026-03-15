import Foundation

enum UIActionDelay {
    static let modalTransitionSeconds = 0.08
    static let followUpActionSeconds = 0.12
    static let transientStateResetSeconds = 2.0
    static let armedDestructiveResetNanoseconds: UInt64 = 5_000_000_000
    static let undoBannerLifetimeNanoseconds: UInt64 = 5_000_000_000
    static let bannerHideAnimationNanoseconds: UInt64 = 220_000_000
}

@MainActor
enum UIActionScheduler {
    static func perform(
        after seconds: Double,
        action: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
