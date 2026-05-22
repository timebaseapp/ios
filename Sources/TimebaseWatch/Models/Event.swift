import Foundation

/// A single upcoming event the Watch displays in Up Next.
///
/// The Watch is calendar-read-only. This type is the watch-side projection
/// of an event from either source:
///  - the iPhone-mirrored snapshot under `timebase.events.v1` (preferred), or
///  - direct EventKit when the Watch is genuinely standalone.
///
/// Its `Codable` shape matches the iOS `persistEventsToAppGroup()` snapshot
/// (`id`, `title`, `startDate`, `endDate`, `timezoneIdentifier`) so the
/// mirrored blob decodes directly.
struct UpcomingEvent: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let timezoneIdentifier: String

    var timezone: TimeZone { TimeZone(identifier: timezoneIdentifier) ?? .current }

    init(id: String, title: String, startDate: Date, endDate: Date, timezoneIdentifier: String) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.timezoneIdentifier = timezoneIdentifier
    }

    static func == (lhs: UpcomingEvent, rhs: UpcomingEvent) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }
}
