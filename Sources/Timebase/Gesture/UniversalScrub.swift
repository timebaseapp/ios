import SwiftUI
import UIKit

/// Vertical-only scrub built on a UIHostingController-backed wrapper. This is
/// the only reliable way for a UIKit UIPanGestureRecognizer to coexist with
/// SwiftUI's TabView .page (which uses its own internal UIScrollView pan).
///
/// The pan recognizer attached here:
///   - fails immediately on horizontal-dominant motion (TabView then claims it)
///   - allows simultaneous recognition with other recognizers via its delegate
///   - feeds vertical deltas back to the SwiftUI store
struct UniversalScrubContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let onVerticalPan: (CGFloat) -> Void
    let onDoubleTap: () -> Void

    func makeUIViewController(context: Context) -> ScrubHostingController<Content> {
        ScrubHostingController(rootView: content, coordinator: context.coordinator)
    }

    func updateUIViewController(_ host: ScrubHostingController<Content>, context: Context) {
        host.rootView = content
        context.coordinator.onVerticalPan = onVerticalPan
        context.coordinator.onDoubleTap = onDoubleTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onVerticalPan: onVerticalPan, onDoubleTap: onDoubleTap)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onVerticalPan: (CGFloat) -> Void
        var onDoubleTap: () -> Void

        init(onVerticalPan: @escaping (CGFloat) -> Void, onDoubleTap: @escaping () -> Void) {
            self.onVerticalPan = onVerticalPan
            self.onDoubleTap = onDoubleTap
        }

        @objc func pan(_ r: UIPanGestureRecognizer) {
            guard r.state == .changed else { return }
            let t = r.translation(in: r.view)
            onVerticalPan(t.y)
            r.setTranslation(.zero, in: r.view)
        }

        @objc func doubleTap(_ r: UITapGestureRecognizer) {
            onDoubleTap()
        }

        // Coexist with TabView's pan + scroll views.
        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        // Don't intercept touches over UIControls so buttons still fire.
        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if touch.view is UIControl { return false }
            return true
        }
    }
}

final class ScrubHostingController<Content: View>: UIHostingController<Content> {
    init(rootView: Content, coordinator: UniversalScrubContainer<Content>.Coordinator) {
        super.init(rootView: rootView)
        view.backgroundColor = .clear

        let pan = VerticalPanRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.pan(_:)))
        pan.delegate = coordinator
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)

        let dbl = UITapGestureRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        dbl.delegate = coordinator
        dbl.cancelsTouchesInView = false
        view.addGestureRecognizer(dbl)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

/// Pan recognizer that fails fast if the user's motion is horizontal-dominant,
/// letting TabView's page-pan claim the gesture.
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
        if dx > 10 && dx > dy * 1.1 {
            state = .failed
        }
    }
}

// MARK: - Haptics wiring (called from ClockListView's scrub handler)

@MainActor
enum ScrubHaptics {
    private static var lastHapticHour: Int?
    private static var lastHapticDay: Int?

    static func update(store: TimebaseStore) {
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

/// Pixels-per-minute used to translate vertical pan into scrub minutes.
let scrubPixelsPerMinute: Double = 0.5
