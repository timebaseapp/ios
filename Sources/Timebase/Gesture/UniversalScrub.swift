import SwiftUI
import UIKit

/// Vertical-only scrub. Built on a UIKit UIPanGestureRecognizer that
/// **fails** on horizontal-dominant motion, leaving TabView's page-swipe
/// pan free to take horizontal gestures. SwiftUI's DragGesture +
/// .simultaneousGesture couldn't reliably co-exist with TabView's pan, so
/// dropping to UIKit here is the only robust path.
extension View {
    func universalScrub() -> some View {
        modifier(UniversalScrubModifier())
    }
}

struct UniversalScrubModifier: ViewModifier {
    @Environment(TimebaseStore.self) private var store

    func body(content: Content) -> some View {
        content
            .background(
                ScrubRecognizerHost(
                    onChange: { dy in
                        store.scrubOffsetMinutes += Double(-dy) / Self.pixelsPerMinute
                        Self.triggerHapticsIfNeeded(store: store)
                    },
                    onEnded: { },
                    onDoubleTap: { store.snapToNow() }
                )
            )
    }

    static let pixelsPerMinute: Double = 0.5

    // Last-haptic state lives in module storage (the recognizer doesn't own
    // it). Simple enough for our needs.
    private static var lastHapticHour: Int?
    private static var lastHapticDay: Int?

    static func triggerHapticsIfNeeded(store: TimebaseStore) {
        guard let home = store.homeCity else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = home.timeZoneObject
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: store.displayDate)
        let h = comps.hour ?? 0
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

private struct ScrubRecognizerHost: UIViewRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnded: () -> Void
    let onDoubleTap: () -> Void

    func makeUIView(context: Context) -> ScrubHostView {
        let v = ScrubHostView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true

        let pan = VerticalPanRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        v.addGestureRecognizer(pan)

        let dbl = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDouble(_:)))
        dbl.numberOfTapsRequired = 2
        dbl.delegate = context.coordinator
        v.addGestureRecognizer(dbl)
        return v
    }

    func updateUIView(_ uiView: ScrubHostView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnded = onEnded
        context.coordinator.onDoubleTap = onDoubleTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange, onEnded: onEnded, onDoubleTap: onDoubleTap) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGFloat) -> Void
        var onEnded: () -> Void
        var onDoubleTap: () -> Void

        init(onChange: @escaping (CGFloat) -> Void, onEnded: @escaping () -> Void, onDoubleTap: @escaping () -> Void) {
            self.onChange = onChange
            self.onEnded = onEnded
            self.onDoubleTap = onDoubleTap
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                let t = recognizer.translation(in: recognizer.view)
                onChange(t.y)
                recognizer.setTranslation(.zero, in: recognizer.view)
            case .ended, .cancelled:
                onEnded()
            default:
                break
            }
        }

        @objc func handleDouble(_ recognizer: UITapGestureRecognizer) {
            onDoubleTap()
        }

        // Coexist with TabView's pan + scroll views.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        // Don't intercept touches over interactive controls (buttons, etc.) —
        // those should get their tap normally.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Allow taps on standard UI controls through.
            if touch.view is UIControl { return false }
            return true
        }
    }
}

/// Background overlay that passes ALL touches through to the SwiftUI content
/// underneath (we still want city rows tappable, contextMenu working, etc.).
/// The gesture recognizers attached observe the touches without claiming them.
final class ScrubHostView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Returning nil makes touches fall through to siblings/underneath.
        // The gesture recognizers attached still observe via UIWindow plumbing.
        return nil
    }
}

/// UIPanGestureRecognizer that **fails** as soon as horizontal motion
/// dominates. This frees TabView's own pan to take horizontal page-swipes.
final class VerticalPanRecognizer: UIPanGestureRecognizer {
    private var firstPoint: CGPoint?

    override func reset() {
        super.reset()
        firstPoint = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        firstPoint = touches.first?.location(in: view?.window)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible,
              let start = firstPoint,
              let now = touches.first?.location(in: view?.window) else { return }
        let dx = abs(now.x - start.x)
        let dy = abs(now.y - start.y)
        // If we've moved meaningfully and the motion is horizontal-dominant,
        // bow out so TabView's pan can take over.
        if (dx > 8 || dy > 8) && dx > dy * 1.1 {
            state = .failed
        }
    }
}
