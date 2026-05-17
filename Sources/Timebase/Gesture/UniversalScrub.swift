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

        let dbl = UITapGestureRecognizer(target: coordinator, action: #selector(UniversalScrubContainer<Content>.Coordinator.doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        dbl.delegate = coordinator
        dbl.cancelsTouchesInView = false
        view.addGestureRecognizer(dbl)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Walk up to find TabView's internal UIScrollView and force its pan
        // to wait for ours to fail. If ours succeeds (vertical scrub), its
        // pan is cancelled → no accidental page switch mid-scrub.
        guard let myPan = panRecognizer else { return }
        var current: UIView? = view
        while let v = current {
            if let sv = v as? UIScrollView {
                sv.panGestureRecognizer.require(toFail: myPan)
                break
            }
            current = v.superview
        }
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
        // Strong bias toward vertical: only bow out if motion is clearly
        // horizontal-dominant. This lets diagonal/wiggly drags still scrub
        // vertically without accidentally swiping pages.
        if dx > 18 && dx > dy * 2.0 {
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
