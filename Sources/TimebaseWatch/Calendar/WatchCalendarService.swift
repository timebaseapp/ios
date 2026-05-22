import Foundation
import EventKit

/// Read-only EventKit access for the **standalone fallback** path only.
///
/// The Watch prefers the iPhone-mirrored snapshot (`timebase.events.v1`) and
/// shows events with zero permission friction. This service is reached only
/// when the Watch is genuinely phone-less: the user taps "Show my events",
/// which triggers a Watch-side calendar prompt. It never writes events.
@MainActor
final class WatchCalendarService {
    private let store = EKEventStore()

    /// Whether the Watch app already holds full calendar access.
    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Requests Watch-side full calendar access. The system does NOT share
    /// the iPhone's grant — this is a separate prompt, which is why it is
    /// gated behind an explicit tap.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Upcoming events within the next `days` days, all-day skipped,
    /// recurring series deduplicated to the next instance. Returns the
    /// watch-side `UpcomingEvent` projection.
    func upcomingEvents(within days: Int = 7) -> [UpcomingEvent] {
        guard hasAccess else { return [] }
        let calendars = store.calendars(for: .event)
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var seenSeries = Set<String>()
        var result: [UpcomingEvent] = []
        for event in events {
            if event.isAllDay { continue }
            if event.endDate <= now { continue }
            let key = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? UUID().uuidString
            if seenSeries.contains(key) { continue }
            seenSeries.insert(key)
            result.append(UpcomingEvent(
                id: event.eventIdentifier ?? key,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                timezoneIdentifier: (event.timeZone ?? .current).identifier
            ))
            if result.count >= 20 { break }
        }
        return result
    }
}
