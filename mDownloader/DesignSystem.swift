import SwiftUI
import UIKit

enum BrandPalette {
    static let background = adaptive(light: 0xF0F5FF, dark: 0x08132F)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x172342)
    static let elevated = adaptive(light: 0xE7EDF8, dark: 0x202B4C)
    static let search = adaptive(light: 0xD9DFEC, dark: 0x303A59)
    static let primaryText = adaptive(light: 0x071331, dark: 0xF8FAFF)
    static let secondaryText = adaptive(light: 0x737D93, dark: 0x9CA6BD)
    static let separator = adaptive(light: 0xD9DEEA, dark: 0x2D3858)
    static let accent = Color(hex: 0x3A5DA7)
    static let lightAccent = Color(hex: 0x6D92E7)
    static let darkAccent = Color(hex: 0x223B83)
    static let arrowRed = Color(hex: 0xF13F5C)

    static let progressGradient = LinearGradient(
        colors: [lightAccent, darkAccent],
        startPoint: .leading,
        endPoint: .trailing
    )

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct CardStyle: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(BrandPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func mDownloaderCard(radius: CGFloat = 24) -> some View {
        modifier(CardStyle(radius: radius))
    }
}

