import SwiftUI

/// Adaptive countdown timer. Precision and refresh rate adapt to how close
/// the target date is — distant events show `5d 12h`, imminent ones tick at
/// 30 Hz with a tenth-of-second sweep.
struct CountdownText: View {
    let target: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let now = context.date
            let delta = target.timeIntervalSince(now)
            buildText(delta: delta)
                .font(.system(size: 38, weight: .heavy))
                .monospacedDigit()
                .kerning(-0.8)
        }
    }

    @ViewBuilder
    private func buildText(delta: TimeInterval) -> some View {
        // Past
        if delta < 0 {
            let abs = -delta
            if abs < 60 {
                Text("now")
            } else {
                Text(pastFormat(abs)) + Text(" ago").foregroundStyle(.secondary)
            }
        }
        // < 1 minute — sub-second sweep with muted tenths
        else if delta < 60 {
            let whole = Int(delta)
            let tenths = Int((delta - Double(whole)) * 10)
            Text("\(whole)") + Text(".\(tenths)s").foregroundStyle(.primary.opacity(0.6))
        }
        // < 1 hour — Mm Ss
        else if delta < 3600 {
            let m = Int(delta) / 60
            let s = Int(delta) % 60
            Text(String(format: "%dm %02ds", m, s))
        }
        // < 1 day — Hh Mm Ss
        else if delta < 86_400 {
            let h = Int(delta) / 3600
            let m = (Int(delta) % 3600) / 60
            let s = Int(delta) % 60
            Text(String(format: "%dh %02dm %02ds", h, m, s))
        }
        // < 30 days — Dd Hh Mm (no seconds; too jittery at this distance)
        else if delta < 30 * 86_400 {
            let d = Int(delta) / 86_400
            let h = (Int(delta) % 86_400) / 3600
            let m = (Int(delta) % 3600) / 60
            Text(String(format: "%dd %dh %02dm", d, h, m))
        }
        // ≥ 30 days — Dd Hh
        else {
            let d = Int(delta) / 86_400
            let h = (Int(delta) % 86_400) / 3600
            Text(String(format: "%dd %dh", d, h))
        }
    }

    private func pastFormat(_ abs: TimeInterval) -> String {
        if abs < 3600 { return "\(Int(abs) / 60)m" }
        if abs < 86_400 { return "\(Int(abs) / 3600)h" }
        return "\(Int(abs) / 86_400)d"
    }
}
