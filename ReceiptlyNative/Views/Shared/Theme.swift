import SwiftUI
import UIKit

// MARK: - Native UIKit blur (reliable on all iOS 16+ devices)

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemThinMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - App colour palette (mirrors theme.js)

enum AppColor {
    static let bg      = Color(hex: "#f4f5f1")
    static let surface = Color(hex: "#ffffff")
    static let card    = Color.black.opacity(0.055)
    static let border  = Color.black.opacity(0.2)
    static let text    = Color(hex: "#050706")
    static let muted   = Color(hex: "#323933")
    static let accent  = Color(hex: "#0f8b5f")
    static let accent2 = Color(hex: "#095d40")
    static let danger  = Color(hex: "#9f2f2f")
    static let success = Color(hex: "#11865a")
    static let warning = Color(hex: "#8a6112")
    static let onAccent = Color(hex: "#f7fffa")
    static let accentBadgeText = Color(hex: "#020a05")

    // Semantic overlays / shadows / special states
    static let dangerSoftFill = danger.opacity(0.12)
    static let dangerSoftBorder = danger.opacity(0.28)
    static let scrimLight = Color.black.opacity(0.28)
    static let scrimMid = Color.black.opacity(0.35)
    static let scrim = Color.black.opacity(0.40)
    static let scrimStrong = Color.black.opacity(0.50)
    static let shadowSoft = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.12)
    static let shadowHeavy = Color.black.opacity(0.20)
    static let glassStroke = Color.white.opacity(0.72)

    // Glass nav / tabbar backgrounds
    static let navGlass = Color(hex: "#f4f5f1").opacity(0.92)
}

// MARK: - Corner radii

enum Radii {
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 20
    static let xxl: CGFloat = 24
}

// MARK: - Reusable card modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radii.lg))
            .overlay(RoundedRectangle(cornerRadius: Radii.lg).stroke(AppColor.border, lineWidth: 1))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColor.muted)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
