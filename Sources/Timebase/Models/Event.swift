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

    static func == (lhs: UpcomingEvent, rhs: UpcomingEvent) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }
}
