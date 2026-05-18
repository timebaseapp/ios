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
    /// Fired once per pinch "step". +1 when the user pinches out past the
    /// threshold, -1 when they pinch in.
    let onPinchStep: (Int) -> Void

    func makeUIViewController(context: Context) -> ScrubHostingController<Content> {
        ScrubHostingController(rootView: content, coordinator: context.coordinator)
    }

    func updateUIViewController(_ host: ScrubHostingController<Content>, context: Context) {
        host.rootView = content
        context.coordinator.onVerticalPan = onVerticalPan
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinchStep = onPinchStep
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onVerticalPan: onVerticalPan, onDoubleTap: onDoubleTap, onPinchStep: onPinchStep)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onVerticalPan: (CGFloat) -> Void
        var onDoubleTap: () -> Void
        var onPinchStep: (Int) -> Void

        /// Cumulative scale baseline for the pinch recognizer. Reset to 1.0
        /// each time a step fires, so continuous pinching keeps stepping.
        private var pinchBaseline: CGFloat = 1.0
        private let pinchOutThreshold: CGFloat = 1.20
        private let pinchInThreshold: CGFloat = 0.83

        init(onVerticalPan: @escaping (CGFloat) -> Void,
             onDoubleTap: @escaping () -> Void,
             onPinchStep: @escaping (Int) -> Void) {
            self.onVerticalPan = onVerticalPan
            self.onDoubleTap = onDoubleTap
            self.onPinchStep = onPinchStep
        }

        @objc func pan(_ r: UIPanGestureRecognizer) {
            guard r.state == .changed else { return }
            let t = r.translation(in: r.view)
            onVerticalPan(t.y)
            r.setTranslation(.zero, in: r.view)
        }

        @objc func handleTbScrubReset(_ r: UITapGestureRecognizer) {
            onDoubleTap()
        }

        @objc func pinch(_ r: UIPinchGestureRecognizer) {
            switch r.state {
            case .began:
                pinchBaseline = 1.0
            case .changed:
                // Step counter — `scale` is cumulative since .began. We
                // compare against our moving baseline so the user can keep
                // pinching past the first step.
                let delta = r.scale / pinchBaseline
                if delta >= pinchOutThreshold {
                    onPinchStep(+1)
                    pinchBaseline = r.scale
                } else if delta <= pinchInThreshold {
                    onPinchStep(-1)
                    pinchBaseline = r.scale
                }
            case .ended, .cancelled, .failed:
                pinchBaseline = 1.0
            default:
                break
            }
        }

        // Coexist with tap / long-press, but NOT with other pans — we want
        // ours and TabView's to be mutually exclusive so vertical scrubbing
        // never coincides with a page swipe.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UIPanGestureRecognizer { return false }
            return true
        }

        // Don't intercept touches over UIControls so buttons still fire.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if touch.view is UIControl { return false }
            return true
        }
    }
}

final class ScrubHostingController<Content: View>: UIHostingController<Content> {
    private var panRecognizer: VerticalPanRecognizer?

    @MainActor
    init(rootView: Content, coordinator: UniversalScrubContainer<Content>.Coordinator) {
        super.init(rootView: rootView)
        view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            self.safeAreaRegions = []
        }

        let pan = VerticalPanRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.pan(_:)))
        pan.delegate = coordinator
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        self.panRecognizer = pan

        let dbl = UITapGestureRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.handleTbScrubReset(_:)))
        dbl.numberOfTapsRequired = 2
        dbl.delegate = coordinator
        dbl.cancelsTouchesInView = false
        view.addGestureRecognizer(dbl)

        // Pinch — coexists with the pan recognizer (different gesture class)
        // so the user can pan-scrub minutes and pinch-jump hours simultaneously
        // if they want, without either recognizer disabling the other.
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.pinch(_:)))
        pinch.delegate = coordinator
        pinch.cancelsTouchesInView = false
        view.addGestureRecognizer(pinch)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    // require(toFail:) is gone — it was making TabView's pan WAIT for ours
    // to fail, which never happened fast enough for horizontal motion and
    // killed single-finger swipes. The recognizer's own early-fail logic
    // (touchesMoved before super) plus shouldRecognizeSimultaneouslyWith
    // returning false for other pans now provides clean mutual exclusion.
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
        // Decide direction BEFORE super processes the touch — otherwise super
        // can transition to .began (at ~10pt default) and fire .changed once
        // with horizontal motion's small vertical component before we get a
        // chance to fail.
        if state == .possible,
           let start = firstPoint,
           let now = touches.first?.location(in: view?.window) {
            let dx = abs(now.x - start.x)
            let dy = abs(now.y - start.y)
            let dist = hypot(now.x - start.x, now.y - start.y)
            // 4pt is enough to read direction reliably. If the dominant
            // axis is horizontal, fail now — TabView's pan can claim.
            if dist >= 4 && dx > dy {
                state = .failed
                return
            }
        }
        super.touchesMoved(touches, with: event)
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
