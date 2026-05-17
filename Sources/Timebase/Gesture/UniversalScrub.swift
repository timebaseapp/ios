import SwiftUI

/// Vertical-only scrub. Horizontal drag is reserved for TabView page swipe.
/// Drag up → advance time. Drag down → rewind. Pure direct manipulation,
/// no inertia, no springback.
struct UniversalScrubModifier: ViewModifier {
    @Environment(TimebaseStore.self) private var store
    @State private var initialOffset: Double = 0
    @State private var dragActive = false
    @State private var lastHapticHour: Int? = nil
    @State private var lastHapticDay: Int? = nil

    static let pixelsPerMinute: Double = 0.5

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            // Simultaneous gesture so TabView's horizontal page-pan still
            // sees the touch. We only ACT on vertical-dominant motion;
            // diagonal/horizontal drags fall through to the TabView.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let dy = value.translation.height
                        let dx = value.translation.width
                        guard Swift.abs(dy) > Swift.abs(dx) * 1.4 else { return }
                        if !dragActive {
                            initialOffset = store.scrubOffsetMinutes
                            dragActive = true
                        }
                        let projected = -dy
                        store.scrubOffsetMinutes = initialOffset + Double(projected) / Self.pixelsPerMinute
                        triggerHapticsIfNeeded()
                    }
                    .onEnded { _ in dragActive = false }
            )
            .onTapGesture(count: 2) { store.snapToNow() }
    }

    private func triggerHapticsIfNeeded() {
        guard let home = store.homeCity else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = home.timeZoneObject
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: store.displayDate)
        let h = comps.hour ?? 0
        // Day boundary fires the heavier haptic first; hour boundary as a fallback.
        let dayKey = ((comps.year ?? 0) * 10000) + ((comps.month ?? 0) * 100) + (comps.day ?? 0)
        if lastHapticDay != dayKey && lastHapticDay != nil {
            Haptics.scrubDayBoundary()
        } else if lastHapticHour != h && lastHapticHour != nil {
            Haptics.scrubHourBoundary()
        }
        lastHapticHour = h
        lastHapticDay = dayKey
    }
}

extension View {
    func universalScrub() -> some View { modifier(UniversalScrubModifier()) }
}
