import WatchKit

/// Wrist haptics for the scrub interaction. The watch Taptic Engine is finer
/// than the iPhone's — the Crown scrub gets a genuinely tactile cadence.
@MainActor
enum WatchHaptics {
    /// Light tap when the scrub hits its ±2-day cap.
    static func scrubCap() {
        WKInterfaceDevice.current().play(.retry)
    }

    /// Confirming haptic when the wearer snaps back to now.
    static func snapToNow() {
        WKInterfaceDevice.current().play(.success)
    }

    /// Soft detent tick as the Crown crosses a scrub step.
    static func scrubTick() {
        WKInterfaceDevice.current().play(.click)
    }

    /// A page change between city cards.
    static func pageChange() {
        WKInterfaceDevice.current().play(.directionUp)
    }
}
