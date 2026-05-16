import SwiftUI

/// OKLCH-based time-of-day color interpolation.
///
/// Two palettes (light / dark). For a fractional hour [0, 24) we interpolate
/// between adjacent anchor stops in OKLCH space — perceptually uniform, smooth
/// at every point. Hue uses the short arc.
enum TimeColor {

    struct Anchor {
        let hour: Double
        let oklch: OKLCH
    }

    // Alto's Adventure / Pasture-inspired palette: muted earthy tones, warm
    // horizon glow at dawn/dusk, long cool stretches at night. Each anchor was
    // chosen so neighbors interpolate to painterly mid-tones — no neon punch.
    static let light: [Anchor] = [
        .init(hour: 0,    oklch: OKLCH(hex: "1E2538")),  // deep midnight indigo
        .init(hour: 3,    oklch: OKLCH(hex: "2A3548")),  // still night, faint lift
        .init(hour: 5.5,  oklch: OKLCH(hex: "5C5A6E")),  // pre-dawn lavender-grey
        .init(hour: 6.5,  oklch: OKLCH(hex: "C4B098")),  // first-light cream-clay
        .init(hour: 8,    oklch: OKLCH(hex: "D9CDB4")),  // morning cream-sage
        .init(hour: 10,   oklch: OKLCH(hex: "C5C3A5")),  // pale olive-sage
        .init(hour: 12,   oklch: OKLCH(hex: "D9C898")),  // warm sand
        .init(hour: 14,   oklch: OKLCH(hex: "C9A874")),  // sun-baked sand
        .init(hour: 16,   oklch: OKLCH(hex: "C4905E")),  // golden afternoon
        .init(hour: 18,   oklch: OKLCH(hex: "B07248")),  // dusk amber
        .init(hour: 19.5, oklch: OKLCH(hex: "8A5440")),  // deep sunset terracotta
        .init(hour: 21,   oklch: OKLCH(hex: "4A4458")),  // twilight purple-grey
        .init(hour: 23,   oklch: OKLCH(hex: "26304A")),  // settling night
        .init(hour: 24,   oklch: OKLCH(hex: "1E2538")),
    ]

    static let dark: [Anchor] = [
        .init(hour: 0,    oklch: OKLCH(hex: "0F1322")),
        .init(hour: 3,    oklch: OKLCH(hex: "171F30")),
        .init(hour: 5.5,  oklch: OKLCH(hex: "3A3848")),
        .init(hour: 6.5,  oklch: OKLCH(hex: "7A6B58")),
        .init(hour: 8,    oklch: OKLCH(hex: "8A806B")),
        .init(hour: 10,   oklch: OKLCH(hex: "7E7C66")),
        .init(hour: 12,   oklch: OKLCH(hex: "8C7E5C")),
        .init(hour: 14,   oklch: OKLCH(hex: "836846")),
        .init(hour: 16,   oklch: OKLCH(hex: "7C5638")),
        .init(hour: 18,   oklch: OKLCH(hex: "6E4530")),
        .init(hour: 19.5, oklch: OKLCH(hex: "5A3528")),
        .init(hour: 21,   oklch: OKLCH(hex: "302C3A")),
        .init(hour: 23,   oklch: OKLCH(hex: "171F30")),
        .init(hour: 24,   oklch: OKLCH(hex: "0F1322")),
    ]

    /// Returns the background color for a city at the given fractional hour.
    /// `scrubMute`: 0 means full saturation, 1 means fully muted.
    static func background(forHour hour: Double, scheme: ColorScheme, scrubMute: Double = 0) -> Color {
        let anchors = (scheme == .dark) ? dark : light
        var lch = interpolate(anchors: anchors, hour: hour)
        if scrubMute > 0 { lch.c *= (1 - scrubMute * 0.6) }
        return Color(lch.toRGBA(alpha: 1))
    }

    /// Returns a two-stop gradient (lighter top, base bottom) for "almost solid
    /// but breathing" row backgrounds — pure solid feels flat next to grain.
    static func backgroundGradient(forHour hour: Double, scheme: ColorScheme, scrubMute: Double = 0) -> [Color] {
        let anchors = (scheme == .dark) ? dark : light
        var base = interpolate(anchors: anchors, hour: hour)
        if scrubMute > 0 { base.c *= (1 - scrubMute * 0.6) }
        // Top: slightly lighter (+L 0.04), faint chroma drop for airiness.
        let top = OKLCH(l: min(1, base.l + 0.035), c: base.c * 0.95, h: base.h)
        // Bottom: a touch deeper for landed weight.
        let bot = OKLCH(l: max(0, base.l - 0.025), c: base.c, h: base.h)
        return [Color(top.toRGBA(alpha: 1)), Color(bot.toRGBA(alpha: 1))]
    }

    /// Returns the appropriate foreground color (near-white or near-black) for
    /// optimal contrast on the given background.
    static func foreground(forHour hour: Double, scheme: ColorScheme) -> Color {
        let anchors = (scheme == .dark) ? dark : light
        let lch = interpolate(anchors: anchors, hour: hour)
        return lch.l < 0.62 ? Color(white: 1) : Color(white: 0.05)
    }

    private static func interpolate(anchors: [Anchor], hour: Double) -> OKLCH {
        let h = (hour.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
        for i in 0 ..< anchors.count - 1 {
            let a = anchors[i], b = anchors[i + 1]
            if h >= a.hour && h <= b.hour {
                let t = (h - a.hour) / (b.hour - a.hour)
                return OKLCH(
                    l: a.oklch.l + (b.oklch.l - a.oklch.l) * t,
                    c: a.oklch.c + (b.oklch.c - a.oklch.c) * t,
                    h: lerpHue(a.oklch.h, b.oklch.h, t)
                )
            }
        }
        return anchors[0].oklch
    }

    private static func lerpHue(_ h1: Double, _ h2: Double, _ t: Double) -> Double {
        var d = h2 - h1
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return ((h1 + d * t).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}

/// OKLCH color (perceptually uniform). L is 0..1, C ≥ 0, H is degrees [0, 360).
struct OKLCH {
    var l: Double
    var c: Double
    var h: Double

    init(l: Double, c: Double, h: Double) { self.l = l; self.c = c; self.h = h }

    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        let oklab = Self.rgbToOklab(r, g, b)
        self.l = oklab.0
        self.c = hypot(oklab.1, oklab.2)
        self.h = (atan2(oklab.2, oklab.1) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    private static func delinearize(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private static func rgbToOklab(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let R = linearize(r), G = linearize(g), B = linearize(b)
        let l = 0.4122214708*R + 0.5363325363*G + 0.0514459929*B
        let m = 0.2119034982*R + 0.6806995451*G + 0.1073969566*B
        let s = 0.0883024619*R + 0.2817188376*G + 0.6299787005*B
        let l_ = cbrt(l), m_ = cbrt(m), s_ = cbrt(s)
        return (
            0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_,
            1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_,
            0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_
        )
    }

    private static func oklabToRgb(_ L: Double, _ a: Double, _ b: Double) -> (Double, Double, Double) {
        let l_ = L + 0.3963377774*a + 0.2158037573*b
        let m_ = L - 0.1055613458*a - 0.0638541728*b
        let s_ = L - 0.0894841775*a - 1.2914855480*b
        let l = l_*l_*l_, m = m_*m_*m_, s = s_*s_*s_
        let R =  4.0767416621*l - 3.3077115913*m + 0.2309699292*s
        let G = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
        let B = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
        return (delinearize(R), delinearize(G), delinearize(B))
    }

    func toRGBA(alpha: Double = 1) -> CGColor {
        let a = c * cos(h * .pi / 180)
        let b = c * sin(h * .pi / 180)
        let (r, g, bl) = Self.oklabToRgb(l, a, b)
        return CGColor(srgbRed: clamp(r), green: clamp(g), blue: clamp(bl), alpha: alpha)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
