import Foundation
import EventKit

struct UpcomingEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let timezone: TimeZone
    let location: String?
    let calendarColor: CGColor?

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.timezone = event.timeZone ?? .current
        self.location = event.location
        self.calendarColor = event.calendar?.cgColor
    }

    #if DEBUG
    /// Direct construction for marketing capture (bypasses EventKit).
    init(marketingId: String, title: String, startDate: Date, endDate: Date, timezone: TimeZone) {
        self.id = marketingId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.timezone = timezone
        self.location = nil
        self.calendarColor = nil
    }
    static func marketing(id: String, title: String, startDate: Date, endDate: Date, tz: TimeZone) -> UpcomingEvent {
        UpcomingEvent(marketingId: id, title: title, startDate: startDate, endDate: endDate, timezone: tz)
    }
    #endif

    static func == (lhs: UpcomingEvent, rhs: UpcomingEvent) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }
}
