import Foundation

/// A single upcoming event the Mac displays in the menubar popover, the
/// floating "what's next" panel, and the Up Next widget.
///
/// Byte-compatible with iOS `persistEventsToAppGroup()` snapshot:
/// `id`, `title`, `startDate`, `endDate`, `timezoneIdentifier`.
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
