import SwiftUI

/// The macOS menubar status item — a small filled circle in the home city's
/// current time-of-day OKLCH color. Reads as the home's "mood" at a glance:
/// deep indigo = home is asleep, warm honey = mid-morning, peach-gold = noon.
/// The user learns to read it without thinking.
struct MenubarStatusLabel: View {
    @Environment(TimebaseMacStore.self) private var store

    @State private var tick = Date()
    /// Re-render once a minute — the color drifts slowly through the day, no
    /// need for second-level ticking in the status item.
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let hour = ClockMath.fractionalHour(in: store.homeTimeZone, date: tick)
        // The menubar varies (light wallpaper vs dark); the deeper iOS `dark`
        // anchor palette tends to render legibly against both backgrounds.
        let color = Palette.background(forHour: hour, scheme: .dark)

        Circle()
            .fill(color)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 14, height: 14)
            .onReceive(timer) { tick = $0 }
    }
}
