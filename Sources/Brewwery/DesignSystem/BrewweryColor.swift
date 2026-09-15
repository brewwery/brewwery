import SwiftUI

/// The Brewwery palette.
///
/// Every value is a direct port of a custom property in `renderer/styles.css`, kept in the
/// same HSL/RGB form as the original so the two can be diffed line by line. The legacy app
/// shipped a dark default and a warm light theme; both are reproduced, and neither is
/// invented.
enum BrewweryColor {
    // MARK: Surfaces
    static let appPanel = themed(dark: .hex(0x111318), light: .hsl(42, 24, 95))
    static let sidebar = themed(dark: .hex(0x0F1115), light: .hsl(40, 19, 88))
    static let titlebar = themed(dark: .hex(0x101216), light: .hsl(40, 20, 92))
    static let background = themed(dark: .hsl(220, 13, 9), light: .hsl(42, 24, 94))
    static let card = themed(dark: .white(0.035), light: .rgb(255, 252, 246, 0.82))
    static let cardHover = themed(dark: .white(0.06), light: .rgb(255, 249, 239, 0.98))
    static let input = themed(dark: .black(0.2), light: .rgb(255, 252, 246, 0.9))
    static let pre = themed(dark: .black(0.2), light: .rgb(255, 252, 246, 0.72))
    static let overlay = themed(dark: .black(0.45), light: .rgb(31, 29, 25, 0.18))
    static let muted = themed(dark: .hsl(220, 10, 13), light: .hsl(42, 18, 87))

    // MARK: Text
    static let foreground = themed(dark: .hsl(38, 22, 92), light: .hsl(32, 16, 12))
    static let mutedForeground = themed(dark: .hsl(220, 9, 62), light: .hsl(32, 9, 39))

    // MARK: Lines
    static let border = themed(dark: .hsl(220, 12, 18), light: .hsl(35, 14, 74))

    // MARK: Accent
    static let accent = themed(dark: .hsl(39, 96, 52), light: .hsl(36, 100, 36))
    static let accentForeground = themed(dark: .hsl(32, 95, 8), light: .hsl(38, 40, 98))
    static let accentSoft = themed(dark: .rgb(245, 158, 11, 0.12), light: .hsl(39, 82, 86))
    static let focusRing = themed(dark: .hsl(39, 96, 58), light: .hsl(36, 100, 34))

    // MARK: Status
    static let success = themed(dark: .hsl(154, 70, 58), light: .hsl(154, 58, 31))
    static let successBackground = themed(dark: .rgb(16, 185, 129, 0.10), light: .hsl(153, 46, 88))
    static let successBorder = themed(dark: .rgb(16, 185, 129, 0.28), light: .hsl(153, 37, 62))

    static let danger = themed(dark: .hsl(0, 86, 72), light: .hsl(1, 70, 43))
    static let dangerBackground = themed(dark: .rgb(239, 68, 68, 0.10), light: .hsl(4, 82, 94))
    static let dangerBorder = themed(dark: .rgb(239, 68, 68, 0.28), light: .hsl(2, 62, 72))

    static let warning = themed(dark: .hsl(39, 96, 58), light: .hsl(36, 100, 34))
    static let warningBackground = themed(dark: .rgb(245, 158, 11, 0.10), light: .hsl(39, 86, 89))
    static let warningBorder = themed(dark: .rgb(245, 158, 11, 0.28), light: .hsl(37, 72, 60))

    /// Casks are tinted violet throughout the legacy UI (Tailwind `purple-500`/`purple-300`).
    static let caskAccent = themed(dark: .hex(0xD8B4FE), light: .hex(0x7E22CE))
    static let caskBackground = themed(dark: .rgb(168, 85, 247, 0.10), light: .rgb(168, 85, 247, 0.12))
    static let caskBorder = themed(dark: .rgb(168, 85, 247, 0.25), light: .rgb(126, 34, 206, 0.35))

    /// Shadow under cards and panels (`--brewwery-shadow-panel`).
    static let panelShadow = themed(dark: .black(0.28), light: .rgb(42, 36, 27, 0.12))

    private static func themed(dark: ColorValue, light: ColorValue) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkAppearance ? dark.nsColor : light.nsColor
        })
    }
}

/// A colour literal in one of the notations the legacy stylesheet used.
enum ColorValue {
    case hsl(Double, Double, Double)
    case rgb(Double, Double, Double, Double)
    case hex(UInt32)
    case white(Double)
    case black(Double)

    var nsColor: NSColor {
        switch self {
        case .hsl(let hue, let saturation, let lightness):
            let (red, green, blue) = Self.rgbComponents(hue: hue, saturation: saturation / 100, lightness: lightness / 100)
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        case .rgb(let red, let green, let blue, let alpha):
            return NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
        case .hex(let value):
            return NSColor(
                srgbRed: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                alpha: 1
            )
        case .white(let alpha):
            return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
        case .black(let alpha):
            return NSColor(srgbRed: 0, green: 0, blue: 0, alpha: alpha)
        }
    }

    /// CSS `hsl()` to sRGB, so the ported values need no manual conversion.
    private static func rgbComponents(
        hue: Double,
        saturation: Double,
        lightness: Double
    ) -> (Double, Double, Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let huePrime = hue.truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(huePrime.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2

        let (red, green, blue): (Double, Double, Double) = switch huePrime {
        case ..<1: (chroma, second, 0)
        case ..<2: (second, chroma, 0)
        case ..<3: (0, chroma, second)
        case ..<4: (0, second, chroma)
        case ..<5: (second, 0, chroma)
        default: (chroma, 0, second)
        }

        return (red + match, green + match, blue + match)
    }
}

extension NSAppearance {
    var isDarkAppearance: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
