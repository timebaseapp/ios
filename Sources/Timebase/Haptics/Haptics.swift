import UIKit

/// Centralized haptic vocabulary. All generators are pre-prepared on init
/// so triggers have low latency.
@MainActor
enum Haptics {

    // Cached generators — prepared once, reused often.
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    private static let light  = UIImpactFeedbackGenerator(style: .light)
    private static let notif  = UINotificationFeedbackGenerator()

    /// Call once at app launch to warm up the haptic engine.
    static func prepare() {
        medium.prepare()
        heavy.prepare()
        rigid.prepare()
        light.prepare()
        notif.prepare()
    }

    /// Crossing an hour boundary during scrub (home city's hour).
    static func scrubHourBoundary() {
        medium.impactOccurred(intensity: 0.7)
        medium.prepare()
    }

    /// Crossing midnight during scrub (notable; stronger than hour).
    static func scrubDayBoundary() {
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }

    /// Hitting the ±2d scrub cap — a "wall" thud.
    static func scrubCapHit() {
        rigid.impactOccurred(intensity: 0.8)
        rigid.prepare()
    }

    /// Snap-to-now: "you've arrived" success.
    static func snapToNow() {
        notif.notificationOccurred(.success)
        notif.prepare()
    }

    /// TabView page change.
    static func pageChanged() {
        medium.impactOccurred(intensity: 0.5)
        medium.prepare()
    }

    /// Pill / button tap confirmation.
    static func buttonPressed() {
        light.impactOccurred(intensity: 0.5)
        light.prepare()
    }
}
