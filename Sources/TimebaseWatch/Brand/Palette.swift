import SwiftUI

/// OKLCH color (perceptually uniform). L is 0..1, C >= 0, H is degrees [0, 360).
/// Verbatim port of the iOS `OKLCH` struct — the sRGB <-> Oklab matrices and
/// the gamma curves are identical so the watch renders the exact same hues.
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

/// OKLCH-based 24-hour time-of-day color interpolation.
///
/// The 14 light + 14 dark anchor stops are copied verbatim from the iOS
/// `TimeColor.swift` palette — they are the brand. The Watch adds an
/// Always-On-Display variant: chroma scaled to ~30% and lightness dropped
/// ~50%, driven by `\.isLuminanceReduced`.
enum Palette {

    struct Anchor {
        let hour: Double
        let oklch: OKLCH
    }

    /// 14 light anchors — verbatim from iOS `TimeColor.light`.
    static let light: [Anchor] = [
        .init(hour: 0,    oklch: OKLCH(hex: "1E2538")),  // midnight indigo
        .init(hour: 3,    oklch: OKLCH(hex: "2A3548")),  // still night
        .init(hour: 5.5,  oklch: OKLCH(hex: "6A5F78")),  // pre-dawn lavender
        .init(hour: 6.5,  oklch: OKLCH(hex: "F2DBA8")),  // first light cream
        .init(hour: 8,    oklch: OKLCH(hex: "F8E5BC")),  // buttery morning
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

    /// 14 dark anchors — verbatim from iOS `TimeColor.dark`.
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

    // MARK: - Interpolation

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

    /// The base OKLCH for an hour, before any muting.
    private static func base(forHour hour: Double, scheme: ColorScheme) -> OKLCH {
        interpolate(anchors: scheme == .dark ? dark : light, hour: hour)
    }

    // MARK: - Public surface

    /// Single solid background color for a fractional hour.
    /// - `scrubMute`: 0 = full saturation, 1 = fully muted (scrub state).
    /// - `aod`: when true the gradient is rendered for Always-On Display —
    ///   chroma scaled to ~30% and lightness dropped ~50%.
    static func background(forHour hour: Double, scheme: ColorScheme,
                           scrubMute: Double = 0, aod: Bool = false) -> Color {
        Color(muted(base(forHour: hour, scheme: scheme), scrubMute: scrubMute, aod: aod).toRGBA(alpha: 1))
    }

    /// Two-stop gradient (lighter top, base bottom) for a card surface —
    /// the "almost solid but breathing" look the iOS row backgrounds use.
    static func backgroundGradient(forHour hour: Double, scheme: ColorScheme,
                                   scrubMute: Double = 0, aod: Bool = false) -> [Color] {
        let m = muted(base(forHour: hour, scheme: scheme), scrubMute: scrubMute, aod: aod)
        let top = OKLCH(l: min(1, m.l + 0.035), c: m.c * 0.95, h: m.h)
        let bot = OKLCH(l: max(0, m.l - 0.025), c: m.c, h: m.h)
        return [Color(top.toRGBA(alpha: 1)), Color(bot.toRGBA(alpha: 1))]
    }

    /// Near-white or near-black foreground for optimal contrast on the
    /// background at `hour`. On AOD the text is pulled toward a dimmer
    /// foreground so it does not glow on a lowered wrist.
    static func foreground(forHour hour: Double, scheme: ColorScheme, aod: Bool = false) -> Color {
        let lch = base(forHour: hour, scheme: scheme)
        if aod {
            // After AOD muting the panel is dark; keep text light but dim.
            return Color(white: 0.78)
        }
        return lch.l < 0.62 ? Color(white: 1) : Color(white: 0.05)
    }

    /// Applies the scrub-mute and AOD-mute levers in OKLCH space.
    ///
    /// Scrub mute reuses the iOS chroma multiplier (`c *= 1 - mute*0.6`).
    /// AOD mute then scales chroma to ~30% and lightness to ~50% — exactly
    /// the "calm, battery-friendly" transform the SCOPE describes. Both are
    /// clean multiplies because OKLCH separates lightness from chroma.
    private static func muted(_ lch: OKLCH, scrubMute: Double, aod: Bool) -> OKLCH {
        var out = lch
        if scrubMute > 0 { out.c *= (1 - scrubMute * 0.6) }
        if aod {
            out.c *= 0.30
            out.l *= 0.50
        }
        return out
    }
}
