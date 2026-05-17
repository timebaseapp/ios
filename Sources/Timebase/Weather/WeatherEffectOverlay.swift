import SwiftUI
import WeatherKit

/// Subtle animated weather overlay layered above a city row's gradient.
/// Uses Canvas + TimelineView for performant frame-driven drawing. Particles
/// are tinted with the row's foreground color so they blend with the palette
/// instead of fighting it.
struct WeatherEffectOverlay: View {
    let condition: WeatherCondition
    let tint: Color   // row's foreground color (white-ish on dark rows, dark on light)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                switch effect(for: condition) {
                case .rain:    drawRain(ctx, size, t)
                case .snow:    drawSnow(ctx, size, t)
                case .clouds:  drawClouds(ctx, size, t)
                case .sun:     drawSun(ctx, size, t)
                case .storm:   drawStorm(ctx, size, t)
                case .fog:     drawFog(ctx, size, t)
                case .none:    ()
                }
            }
            .blendMode(.softLight)
            .opacity(0.85)
        }
        .allowsHitTesting(false)
    }

    private enum Effect { case rain, snow, clouds, sun, storm, fog, none }

    private func effect(for c: WeatherCondition) -> Effect {
        switch c {
        case .clear, .mostlyClear, .hot:
            return .sun
        case .cloudy, .mostlyCloudy, .partlyCloudy, .breezy, .windy:
            return .clouds
        case .drizzle, .rain, .heavyRain, .sunShowers,
             .isolatedThunderstorms:
            return .rain
        case .snow, .heavySnow, .flurries, .blizzard, .sleet, .freezingRain,
             .freezingDrizzle, .wintryMix, .hail, .blowingSnow, .sunFlurries:
            return .snow
        case .thunderstorms, .strongStorms, .hurricane, .tropicalStorm:
            return .storm
        case .foggy, .haze, .smoky, .frigid:
            return .fog
        default:
            return .none
        }
    }

    // MARK: - Effects

    private func drawRain(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let count = 14
        for i in 0..<count {
            // Each streak has a stable column based on `i`, but its vertical
            // position cycles through the row continuously.
            let seed = Double(i) * 13.7
            let x = (seed.truncatingRemainder(dividingBy: 1.0) * size.width)
            let phase = (t * 1.2 + Double(i) * 0.41).truncatingRemainder(dividingBy: 1.0)
            let y = phase * size.height
            let streak = Path { p in
                p.move(to: CGPoint(x: x, y: y - 6))
                p.addLine(to: CGPoint(x: x + 1.6, y: y + 6))
            }
            ctx.stroke(streak, with: .color(tint.opacity(0.30)), lineWidth: 1.0)
        }
    }

    private func drawSnow(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let count = 18
        for i in 0..<count {
            let seed = Double(i) * 17.9
            let baseX = (seed.truncatingRemainder(dividingBy: 1.0) * size.width)
            let sway = sin(t * 0.7 + Double(i)) * 6
            let phase = (t * 0.30 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1.0)
            let y = phase * size.height
            let r = 1.0 + (seed * 0.31).truncatingRemainder(dividingBy: 1.0) * 1.2
            let dot = Path(ellipseIn: CGRect(x: baseX + sway, y: y, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(tint.opacity(0.55)))
        }
    }

    private func drawClouds(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        // Three soft horizontal puffs drifting at different rates.
        for i in 0..<3 {
            let speed = 8.0 + Double(i) * 4.0
            let baseY = size.height * (0.20 + Double(i) * 0.30)
            let x = (t * speed).truncatingRemainder(dividingBy: size.width + 200) - 100
            let w: CGFloat = 110 + CGFloat(i) * 30
            let h: CGFloat = 18 + CGFloat(i) * 4
            let cloud = Path(roundedRect: CGRect(x: x, y: baseY, width: w, height: h),
                             cornerRadius: h / 2)
            ctx.fill(cloud, with: .color(tint.opacity(0.10)))
        }
    }

    private func drawSun(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        // A gentle radial pulse at top-right — feels like sunshine catching
        // the edge of the row.
        let pulse = (sin(t * 0.6) + 1) / 2     // 0..1
        let r = 22 + pulse * 10
        let cx = size.width - 32
        let cy: CGFloat = 18
        let glow = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.fill(glow, with: .radialGradient(
            Gradient(colors: [tint.opacity(0.20), tint.opacity(0)]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: r
        ))
    }

    private func drawStorm(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        // Constant rain with an occasional flash.
        drawRain(ctx, size, t)
        // Flash every ~6 seconds for ~0.15 sec.
        let cyc = t.truncatingRemainder(dividingBy: 6.0)
        if cyc < 0.15 {
            let flash = Path(CGRect(origin: .zero, size: size))
            ctx.fill(flash, with: .color(.white.opacity(0.18 * (1 - cyc / 0.15))))
        }
    }

    private func drawFog(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        // Two slow horizontal bands of haze sweeping across.
        for i in 0..<2 {
            let speed = 6.0 + Double(i) * 3.0
            let baseY = size.height * (0.35 + Double(i) * 0.25)
            let x = (t * speed).truncatingRemainder(dividingBy: size.width + 300) - 150
            let band = Path(roundedRect: CGRect(x: x, y: baseY, width: 180, height: 12),
                            cornerRadius: 6)
            ctx.fill(band, with: .color(tint.opacity(0.08)))
        }
    }
}
