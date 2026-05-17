import SwiftUI

/// Trimmed-down copy of the host app's `TimeColor` palette so the widget
/// renders the same gradients without pulling in the entire app target.
enum WidgetTimeColor {
    private static let stops: [(Double, String)] = [
        (0,    "1E2538"),
        (3,    "2A3548"),
        (5.5,  "6A5F78"),
        (6.5,  "F2DBA8"),
        (8,    "F8E5BC"),
        (10,   "F8D89E"),
        (12,   "F8C788"),
        (14,   "ECB070"),
        (16,   "D89255"),
        (18,   "C56E48"),
        (19.5, "A55048"),
        (21,   "5A4960"),
        (23,   "2A3550"),
        (24,   "1E2538"),
    ]

    /// Top + bottom gradient stops for a row at a given fractional hour.
    static func gradient(forHour hour: Double) -> [Color] {
        let base = colorAt(hour)
        let top = base.lighter(by: 0.05)
        let bot = base.darker(by: 0.04)
        return [top, bot]
    }

    static func foreground(forHour hour: Double) -> Color {
        // sRGB luminance approximation — pick black-ish or white-ish for
        // contrast.
        let base = colorAt(hour)
        let lum = base.relativeLuminance
        return lum < 0.55 ? Color(white: 1.0) : Color(white: 0.06)
    }

    private static func colorAt(_ hour: Double) -> Color {
        let h = ((hour.truncatingRemainder(dividingBy: 24)) + 24).truncatingRemainder(dividingBy: 24)
        for i in 0 ..< stops.count - 1 {
            let (a, ah) = stops[i]
            let (b, bh) = stops[i + 1]
            if h >= a && h <= b {
                let t = (h - a) / (b - a)
                return Color(hex: ah).blend(to: Color(hex: bh), t: t)
            }
        }
        return Color(hex: stops[0].1)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8)  & 0xFF) / 255.0,
            blue:  Double(v & 0xFF) / 255.0
        )
    }

    func blend(to other: Color, t: Double) -> Color {
        // Approximate RGB linear blend.
        let a = uiValues(); let b = other.uiValues()
        return Color(
            red:   a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue:  a.b + (b.b - a.b) * t
        )
    }

    func lighter(by amount: Double) -> Color {
        let c = uiValues()
        return Color(red: min(1, c.r + amount), green: min(1, c.g + amount), blue: min(1, c.b + amount))
    }

    func darker(by amount: Double) -> Color {
        let c = uiValues()
        return Color(red: max(0, c.r - amount), green: max(0, c.g - amount), blue: max(0, c.b - amount))
    }

    var relativeLuminance: Double {
        let c = uiValues()
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    private func uiValues() -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }
}
