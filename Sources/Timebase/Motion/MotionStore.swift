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
    private let queue = OperationQueue()
    private let smoothing = 0.12   // low-pass alpha

    init() {
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0   // 30 Hz
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Roll is in radians; clamp to ±π/3 for usable parallax range,
            // then normalize to [-1, +1].
            let r = max(-1.05, min(1.05, motion.attitude.roll / (.pi / 3)))
            let p = max(-1.05, min(1.05, motion.attitude.pitch / (.pi / 3)))
            Task { @MainActor in
                self.roll  = self.roll  + (r - self.roll)  * self.smoothing
                self.pitch = self.pitch + (p - self.pitch) * self.smoothing
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
