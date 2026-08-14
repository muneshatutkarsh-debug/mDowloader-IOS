import SwiftUI
import UIKit

// MARK: - Theme model

/// The app-wide visual theme, chosen in Settings and *separate* from the
/// light/dark/system appearance ("mood"). `basic` is the original clean,
/// system-driven look; `original` themes the whole UI with the mDownloader
/// logo colors. New installs default to `.original`.
enum AppColorTheme: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case original = "Original"

    var id: String { rawValue }
    var title: String { rawValue }
    var subtitle: String {
        switch self {
        case .basic: "Clean system look"
        case .original: "Themed with the mDownloader logo"
        }
    }
}

/// Observable holder for the current `AppColorTheme`. A shared singleton so the
/// static color tokens below can resolve the active theme, while views observe
/// it through the environment for live, in-place updates.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let storageKey = "colorTheme"

    @Published var theme: AppColorTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        // Default to Original on first launch (no stored preference yet).
        theme = AppColorTheme(rawValue: raw ?? "") ?? .original
    }

    var isOriginal: Bool { theme == .original }

    /// Reads the stored theme without touching the published property, for use
    /// when configuring a Live Activity off the main actor.
    static var storedIsOriginal: Bool {
        (UserDefaults.standard.string(forKey: storageKey) ?? AppColorTheme.original.rawValue)
            != AppColorTheme.basic.rawValue
    }
}

// MARK: - Color helpers

private func idmRGB(_ hex: UInt) -> (CGFloat, CGFloat, CGFloat) {
    (CGFloat((hex >> 16) & 0xFF) / 255,
     CGFloat((hex >> 8) & 0xFF) / 255,
     CGFloat(hex & 0xFF) / 255)
}

/// A solid color from a 24-bit hex literal.
private func idmHex(_ value: UInt, _ alpha: CGFloat = 1) -> Color {
    let c = idmRGB(value)
    return Color(.sRGB, red: Double(c.0), green: Double(c.1), blue: Double(c.2), opacity: Double(alpha))
}

/// A color that adapts to light/dark automatically (used by the Original theme).
private func idmDynamic(light: UInt, lightAlpha: CGFloat = 1,
                        dark: UInt, darkAlpha: CGFloat = 1) -> Color {
    Color(uiColor: UIColor { trait in
        let useDark = trait.userInterfaceStyle == .dark
        let c = idmRGB(useDark ? dark : light)
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: useDark ? darkAlpha : lightAlpha)
    })
}

// MARK: - Palette
// The accent + neutrals resolve dynamically from the active theme. In `basic`
// they map to system colors (so the app reads like a first-party Apple app); in
// `original` they map to the mDownloader logo palette (deep logo-blue in dark,
// light blue-tinted in light) and adapt to the appearance automatically.
extension Color {
    private static var original: Bool { ThemeManager.shared.isOriginal }

    /// Primary accent / interactive tint.
    static var idmAccent: Color {
        original ? idmDynamic(light: 0x34549A, dark: 0x6E90E6) : Color(uiColor: .systemBlue)
    }
    /// Backwards-compatible alias used by older views.
    static var idmBlue: Color { idmAccent }

    /// High-contrast primary label.
    static var idmInk: Color {
        original ? idmDynamic(light: 0x0C1430, dark: 0xFFFFFF) : Color(uiColor: .label)
    }
    /// Muted secondary label.
    static var idmSecondary: Color {
        original ? idmDynamic(light: 0x5C6474, dark: 0x9AA2B4) : Color(uiColor: .secondaryLabel)
    }
    /// Hairline separator for custom surfaces.
    static var idmHairline: Color {
        original ? idmDynamic(light: 0x121C3C, lightAlpha: 0.10, dark: 0xFFFFFF, darkAlpha: 0.08)
                 : Color(uiColor: .separator)
    }
    /// Soft ambient shadow.
    static var idmShadow: Color { Color.black.opacity(original ? 0.20 : 0.10) }

    // Surfaces (Original theme)
    static var idmCard: Color { idmDynamic(light: 0xFFFFFF, dark: 0x151E3B) }
    static var idmTile: Color { idmDynamic(light: 0xE3EAF9, dark: 0x1D2748) }
    static var idmTrack: Color {
        original ? idmDynamic(light: 0x0C1430, lightAlpha: 0.12, dark: 0xFFFFFF, darkAlpha: 0.16)
                 : Color(uiColor: .tertiarySystemFill)
    }
    static var idmBgTop: Color { idmDynamic(light: 0xF1F5FE, dark: 0x101A3E) }
    static var idmBgBottom: Color { idmDynamic(light: 0xE7EEFB, dark: 0x090E24) }

    // Brand tokens (fixed, theme-independent)
    static let idmArrowRed = idmHex(0xEC445B)
    static let idmGradTop = idmHex(0x4F72BE)
    static let idmGradBottom = idmHex(0x2E4088)
}

/// The Original progress/fill gradient (logo blues), left-to-right.
private var idmFillGradient: LinearGradient {
    LinearGradient(colors: [.idmGradTop, .idmGradBottom], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Background
/// The app backdrop. In `basic` it's the plain system grouped background; in
/// `original` it's a subtle vertical logo-blue gradient (deep in dark, light
/// blue-tinted in light) so the floating glass navigation reads clearly.
struct IDMBackground: View {
    var body: some View {
        Group {
            if ThemeManager.shared.isOriginal {
                LinearGradient(colors: [.idmBgTop, .idmBgBottom], startPoint: .top, endPoint: .bottom)
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surface card
/// A clean grouped-list style surface. Basic uses the system grouped surface;
/// Original uses a themed card with a hairline so it reads over the gradient.
struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 20
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        if ThemeManager.shared.isOriginal {
            content
                .padding(padding)
                .background(Color.idmCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.idmHairline, lineWidth: 1)
                )
        } else {
            content
                .padding(padding)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        }
    }
}

extension View {
    func glassCard(radius: CGFloat = 20, padding: CGFloat = 0) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }
}

// MARK: - Symbol tile
/// A compact icon tile. `filled` renders an accent (Original: gradient) tile
/// with a white glyph; otherwise a subtle neutral tile with an accent glyph.
struct SymbolTile: View {
    let symbol: String
    var size: CGFloat = 56
    var filled = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(tileStyle)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .foregroundStyle(filled ? Color.white : Color.idmAccent)
            )
    }

    private var tileStyle: AnyShapeStyle {
        let original = ThemeManager.shared.isOriginal
        if filled {
            return original
                ? AnyShapeStyle(LinearGradient(colors: [.idmGradTop, .idmGradBottom], startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(Color.idmAccent)
        } else {
            return original ? AnyShapeStyle(Color.idmTile) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill))
        }
    }
}

/// A neutral tile for the full-color file-type emoji shown in the mockups.
struct EmojiTile: View {
    let emoji: String
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(ThemeManager.shared.isOriginal ? Color.idmTile : Color(uiColor: .tertiarySystemFill))
            .frame(width: size, height: size)
            .overlay {
                Text(emoji)
                    .font(.system(size: size * 0.52))
                    .minimumScaleFactor(0.7)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Page title
/// Large, San Francisco page title for a native feel.
struct PageTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.idmInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Progress
/// Progress bar. In `basic` it's a slim accent capsule; in `original` it's a
/// thicker logo-blue gradient fill led by a small red "arrow" ball while a
/// transfer is in progress.
struct BlueProgressView: View {
    let progress: Double
    var showsBall: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        let original = ThemeManager.shared.isOriginal
        let barH: CGFloat = original ? 7 : 6
        let ballD: CGFloat = 13
        let overall: CGFloat = original ? ballD : barH
        return GeometryReader { proxy in
            let w = proxy.size.width
            let fillW = max(0, w * clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.idmTrack)
                    .frame(height: barH)
                Capsule()
                    .fill(original ? AnyShapeStyle(idmFillGradient) : AnyShapeStyle(Color.idmAccent))
                    .frame(width: fillW, height: barH)
                if original && showsBall && clamped > 0.001 && clamped < 0.999 {
                    Circle()
                        .fill(Color.idmArrowRed)
                        .frame(width: ballD, height: ballD)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                        .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                        .offset(x: min(fillW, w) - ballD / 2)
                }
            }
            .frame(height: overall)
        }
        .frame(height: overall)
        .animation(.easeOut(duration: 0.25), value: progress)
    }
}
