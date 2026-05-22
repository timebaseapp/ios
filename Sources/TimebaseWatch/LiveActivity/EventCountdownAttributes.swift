import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// =====================================================================
//  VENDORED VERBATIM COPY — DO NOT DIVERGE FROM iOS.
//
//  This struct is a copy of the iOS app's
//  `LiveActivity/EventCountdownAttributes.swift`. It exists so the Watch
//  can surface the iPhone's Timebase Live Activity natively in the Smart
//  Stack / side-of-display widget.
//
//  This is a PROTOCOL-LEVEL CONTRACT, not shared behavior. The two structs
//  (iOS + watchOS) must stay BYTE-COMPATIBLE in their `Codable`
//  representation — that compatibility is the entire coupling. watchOS
//  surfaces the activity automatically; the Watch never drives it.
//
//  `ActivityKit` is not part of every watchOS SDK slice, so the
//  `ActivityAttributes` conformance is gated behind `canImport`. The
//  underlying `Codable` shape — `homeTzIdentifier`, `eventTzIdentifier`,
//  and `ContentState { title, start }` — is identical either way, which is
//  what keeps it byte-compatible with iOS.
//
//  >>> If iOS ever changes this struct, change this file in LOCKSTEP. <<<
// =====================================================================

#if canImport(ActivityKit)

/// Shape of the Live Activity for an upcoming event.
struct EventCountdownAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var start: Date
    }

    /// Home tz identifier (e.g., "America/Los_Angeles")
    public var homeTzIdentifier: String
    /// Event's local tz identifier
    public var eventTzIdentifier: String
}

#else

/// Fallback when `ActivityKit` is unavailable on this watchOS SDK slice —
/// the same `Codable` shape, so the byte-compatible contract still holds.
struct EventCountdownAttributes: Codable, Hashable {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var start: Date
    }
    public var homeTzIdentifier: String
    public var eventTzIdentifier: String
}

#endif
