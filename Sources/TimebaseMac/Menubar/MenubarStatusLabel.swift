import SwiftUI
import AppKit

/// The macOS menubar status item — a small filled circle in the home city's
/// current time-of-day OKLCH color. Renders in COLOR (bypassing macOS's
/// default template-icon treatment) by drawing a SwiftUI view via
/// `ImageRenderer` into an `NSImage` with `isTemplate = false`. Updates once
/// a minute as the home's hour drifts.
struct MenubarStatusLabel: View {
    @Environment(TimebaseMacStore.self) private var store

    @State private var icon: NSImage = NSImage(size: NSSize(width: 18, height: 18))
    @State private var tick = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(nsImage: icon)
            .renderingMode(.original)
            .onAppear { refreshIcon() }
            .onReceive(timer) { now in
                tick = now
                refreshIcon()
            }
            .onChange(of: store.homeCityId) { _, _ in refreshIcon() }
    }

    @MainActor
    private func refreshIcon() {
        let hour = ClockMath.fractionalHour(in: store.homeTimeZone, date: Date())
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)

        let iconView = ZStack {
            Circle()
                .fill(LinearGradient(colors: gradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 0.5)
        }
        .frame(width: 16, height: 16)
        .padding(1)

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let nsImage = renderer.nsImage else { return }
        nsImage.isTemplate = false
        icon = nsImage
    }
}
