import SwiftUI
import UIKit

/// One universal pan that translates `dx + (-dy)` into a scrub delta.
/// Up-and-right advances time, down-and-left rewinds.
struct UniversalScrubModifier: ViewModifier {
    @Environment(TimebaseStore.self) private var store
    @State private var initialOffset: Double = 0
    @State private var lastHapticHour: Int? = nil
    @State private var velocity: Double = 0
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastDragTime: Date = .distantPast
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    static let pixelsPerMinute: Double = 0.5

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if lastDragTime == .distantPast {
                            initialOffset = store.scrubOffsetMinutes
                            lastDragLocation = value.startLocation
                            lastDragTime = .now
                            haptic.prepare()
                        }
                        let dx = value.translation.width
                        let dy = -value.translation.height
                        let projected = dx + dy
                        let newOffset = initialOffset + Double(projected) * (1.0 / Self.pixelsPerMinute)

                        // Velocity tracking for inertia.
                        let now = Date.now
                        let dt = now.timeIntervalSince(lastDragTime)
                        if dt > 0 {
                            let instDx = Double((value.location.x - lastDragLocation.x) + (lastDragLocation.y - value.location.y))
                            velocity = 0.7 * velocity + 0.3 * (instDx / Self.pixelsPerMinute / dt)
                        }
                        lastDragLocation = value.location
                        lastDragTime = now

                        store.scrubOffsetMinutes = newOffset
                        triggerHapticIfNeeded()
                    }
                    .onEnded { _ in
                        applyInertia()
                        lastDragTime = .distantPast
                    }
            )
            .onTapGesture(count: 2) { store.snapToNow() }
    }

    private func triggerHapticIfNeeded() {
        guard let home = store.homeCity else { return }
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = home.timeZoneObject
        let h = cal.component(.hour, from: store.displayDate)
        if lastHapticHour != h {
            haptic.impactOccurred(intensity: 0.4)
            lastHapticHour = h
        }
    }

    private func applyInertia() {
        let decay = 0.94
        var v = velocity * (1.0/60.0)  // approx per-frame
        guard abs(v) > 0.5 else { velocity = 0; return }
        Task { @MainActor in
            while abs(v) > 0.05 {
                store.scrubOffsetMinutes += v
                v *= decay
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            velocity = 0
        }
    }
}

extension View {
    func universalScrub() -> some View { modifier(UniversalScrubModifier()) }
}
