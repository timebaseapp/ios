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

    // Palette philosophy: night feels calm and rested (muted, low chroma, cool);
    // daytime feels bright and alive (high luminance, warm peach/honey/amber
    // hues, moderate chroma — never neon). Sunrise/sunset bridge the two
    // worlds with rising/falling warmth.
    static let light: [Anchor] = [
        .init(hour: 0,    oklch: OKLCH(hex: "1E2538")),  // midnight indigo, calm
        .init(hour: 3,    oklch: OKLCH(hex: "2A3548")),  // still night
        .init(hour: 5.5,  oklch: OKLCH(hex: "6A5F78")),  // pre-dawn lavender
        .init(hour: 6.5,  oklch: OKLCH(hex: "F2DBA8")),  // first light, warm cream
        .init(hour: 8,    oklch: OKLCH(hex: "F8E5BC")),  // bright buttery morning
        .init(hour: 10,   oklch: OKLCH(hex: "F8D89E")),  // mid-morning honey
        .init(hour: 12,   oklch: OKLCH(hex: "F8C788")),  // midday peach-gold
        .init(hour: 14,   oklch: OKLCH(hex: "ECB070")),  // sun-warmed honey
        .init(hour: 16,   oklch: OKLCH(hex: "D89255")),  // golden afternoon
        .init(hour: 18,   oklch: OKLCH(hex: "C56E48")),  // dusk rose-amber
        .init(hour: 19.5, oklch: OKLCH(hex: "A55048")),  // sunset dusty rose
        .init(hour: 21,   oklch: OKLCH(hex: "5A4960")),  // twilight purple
        .init(hour: 23,   oklch: OKLCH(hex: "2A3550")),  // settling night
        .init(hour: 24,   oklch: OKLCH(hex: "1E2538")),
    ]

    static let dark: [Anchor] = [
        .init(hour: 0,    oklch: OKLCH(hex: "0F1322")),
        .init(hour: 3,    oklch: OKLCH(hex: "171F30")),
        .init(hour: 5.5,  oklch: OKLCH(hex: "423D52")),
        .init(hour: 6.5,  oklch: OKLCH(hex: "A8916A")),
        .init(hour: 8,    oklch: OKLCH(hex: "B5A076")),
        .init(hour: 10,   oklch: OKLCH(hex: "B59866")),
        .init(hour: 12,   oklch: OKLCH(hex: "B58A58")),
        .init(hour: 14,   oklch: OKLCH(hex: "A87648")),
        .init(hour: 16,   oklch: OKLCH(hex: "996038")),
        .init(hour: 18,   oklch: OKLCH(hex: "884A30")),
        .init(hour: 19.5, oklch: OKLCH(hex: "703230")),
        .init(hour: 21,   oklch: OKLCH(hex: "382E3A")),
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
