import SwiftUI
import UIKit

/// One universal pan that translates `dx + (-dy)` into a scrub delta.
/// Up-and-right advances time, down-and-left rewinds. Pure direct
/// manipulation — no inertia, no momentum, no springback. The world moves
/// with your finger and stops the moment you release.
struct UniversalScrubModifier: ViewModifier {
    @Environment(TimebaseStore.self) private var store
    @State private var initialOffset: Double = 0
    @State private var dragActive = false
    @State private var lastHapticHour: Int? = nil
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    static let pixelsPerMinute: Double = 0.5

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !dragActive {
                            initialOffset = store.scrubOffsetMinutes
                            dragActive = true
                            haptic.prepare()
                        }
                        let projected = value.translation.width + (-value.translation.height)
                        store.scrubOffsetMinutes = initialOffset + Double(projected) / Self.pixelsPerMinute
                        triggerHapticIfNeeded()
                    }
                    .onEnded { _ in
                        dragActive = false
                    }
            )
            .onTapGesture(count: 2) { store.snapToNow() }
    }

    private func triggerHapticIfNeeded() {
        guard let home = store.homeCity else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = home.timeZoneObject
        let h = cal.component(.hour, from: store.displayDate)
        if lastHapticHour != h {
            haptic.impactOccurred(intensity: 0.4)
            lastHapticHour = h
        }
    }
}

extension View {
    func universalScrub() -> some View { modifier(UniversalScrubModifier()) }
}
