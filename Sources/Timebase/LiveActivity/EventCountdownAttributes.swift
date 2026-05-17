import Foundation
import ActivityKit

/// Shape of the Live Activity for an upcoming event. The static attributes
/// hold values that don't change for the lifetime of the activity
/// (timezones); ContentState holds values that DO (title, start — start can
/// shift if the event moves in the calendar).
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
