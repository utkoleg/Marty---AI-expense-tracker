import SwiftUI
import UIKit

enum AppPreferences {
    static let darkModeEnabledKey = "app.dark_mode_enabled"
    static let appLanguageKey = "app.language"
    static let baseCurrencyKey = "app.base_currency"
}

private extension UIColor {
    static func dynamic(light: String, dark: String) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
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

// MARK: - App palette

enum AppColor {
    static let bg = Color(uiColor: .dynamic(light: "#EEF3F7", dark: "#0A0E13"))
    static let surface = Color(uiColor: .dynamic(light: "#DEE6EE", dark: "#141B23"))
    static let elevated = Color(uiColor: .dynamic(light: "#FFFFFF", dark: "#1C2630"))
    static let tertiarySurface = Color(uiColor: .dynamic(light: "#F7FAFD", dark: "#273340"))
    static let border = Color(uiColor: .dynamic(light: "#C8D2DD", dark: "#435061"))
    static let hairline = Color(uiColor: .dynamic(light: "#D7E0E8", dark: "#536274"))
    static let text = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let accent = Color(uiColor: .dynamic(light: "#156A49", dark: "#35D091"))
    static let accent2 = Color(uiColor: .dynamic(light: "#0D563A", dark: "#1FA876"))
    static let accentSoft = Color(uiColor: .dynamic(light: "#D8F0E6", dark: "#173628"))
    static let accentMuted = Color(uiColor: .dynamic(light: "#E7F6EF", dark: "#11281E"))
    static let onAccent = Color.white
    static let danger = Color(uiColor: .systemRed)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let accentBadgeText = Color.white
    static let scrimLight = Color.black.opacity(0.18)
    static let scrimMid = Color.black.opacity(0.26)
    static let scrim = Color.black.opacity(0.34)
    static let scrimStrong = Color.black.opacity(0.46)
    static let shadowSoft = Color(uiColor: .dynamic(light: "#000000", dark: "#000000")).opacity(0.08)
    static let shadowMedium = Color(uiColor: .dynamic(light: "#000000", dark: "#000000")).opacity(0.14)
    static let shadowHeavy = Color(uiColor: .dynamic(light: "#000000", dark: "#000000")).opacity(0.2)
    static let dangerSoftFill = danger.opacity(0.1)
    static let dangerSoftBorder = danger.opacity(0.2)
}

enum AppGradient {
    static let primary = LinearGradient(
        colors: [AppColor.accent, AppColor.accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func tintedSurface(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [AppColor.elevated, color.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tintedFill(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.22), color.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func categoryBadge(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.98), color.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColor.bg

            Circle()
                .fill(primaryGlowColor.opacity(colorScheme == .dark ? 0.17 : 0.24))
                .frame(width: 300, height: 300)
                .blur(radius: 34)
                .offset(x: -130, y: -250)

            Circle()
                .fill(secondaryGlowColor.opacity(colorScheme == .dark ? 0.12 : 0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: 160, y: -160)

            Circle()
                .fill(primaryGlowColor.opacity(colorScheme == .dark ? 0.1 : 0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 36)
                .offset(x: -170, y: 320)
        }
        .ignoresSafeArea()
    }

    private var primaryGlowColor: Color {
        if colorScheme == .dark {
            return AppColor.accent
        }

        return Color(uiColor: UIColor(hex: "#0A5A3E"))
    }

    private var secondaryGlowColor: Color {
        if colorScheme == .dark {
            return AppColor.accent2
        }

        return Color(uiColor: UIColor(hex: "#084730"))
    }
}

// MARK: - Corner radii

enum Radii {
    static let sm: CGFloat  = 10
    static let md: CGFloat  = 14
    static let lg: CGFloat  = 18
    static let xl: CGFloat  = 22
    static let xxl: CGFloat = 28
}

// MARK: - Shared surfaces

struct CardStyle: ViewModifier {
    var fill: Color = AppColor.elevated
    var stroke: Color = AppColor.border
    var shadow: Color = AppColor.shadowSoft

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: shadow, radius: 20, x: 0, y: 10)
    }
}

extension View {
    func cardStyle(fill: Color = AppColor.elevated, stroke: Color = AppColor.border) -> some View {
        modifier(CardStyle(fill: fill, stroke: stroke))
    }

    func appBackground() -> some View {
        background(AppBackgroundView())
    }

    func appSectionPadding() -> some View {
        padding(.horizontal, 20)
            .padding(.top, 20)
    }
}

struct SymbolBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 14
    var weight: Font.Weight = .semibold

    private var iconSize: CGFloat { size * 0.42 }

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: iconSize, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CategoryIconView: View {
    let info: CategoryInfo
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 14
    var weight: Font.Weight = .semibold

    private var emojiSize: CGFloat { size * 0.48 }

    var body: some View {
        Text(info.emoji)
            .font(.system(size: emojiSize))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(info.color.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(info.color.opacity(0.3), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct EmptyStateView: View {
    let systemName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            SymbolBadge(systemName: systemName, color: AppColor.accent, size: 56, cornerRadius: 18)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.text)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct SummaryChip: View {
    let title: String
    let value: String
    let systemName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 14, alignment: .leading)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(AppColor.muted)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.muted)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
