import Foundation
import CoreMotion
import Observation

/// Smoothed device-attitude probe. Pipes roll (left-right tilt) and pitch
/// (forward-back tilt) into normalized `[-1, +1]` values that views can
/// read to shift gradient endpoints for a parallax / "fluid glass" feel.
@Observable
@MainActor
final class MotionStore {
    /// Smoothed [-1, +1]. Positive roll = tilted right.
    var roll: Double = 0
    /// Smoothed [-1, +1]. Positive pitch = tilted forward (top of device away).
    var pitch: Double = 0

    private let manager = CMMotionManager()
    private let smoothing = 0.12   // low-pass alpha

    init() {}

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        // Drive the callback on the main queue and use assumeIsolated so we
        // don't trip Swift 6's actor-isolation assertion when mutating our
        // @MainActor-isolated stored properties.
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            MainActor.assumeIsolated {
                let r = max(-1.05, min(1.05, motion.attitude.roll  / (.pi / 3)))
                let p = max(-1.05, min(1.05, motion.attitude.pitch / (.pi / 3)))
                self.roll  = self.roll  + (r - self.roll)  * self.smoothing
                self.pitch = self.pitch + (p - self.pitch) * self.smoothing
            }
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }
}
