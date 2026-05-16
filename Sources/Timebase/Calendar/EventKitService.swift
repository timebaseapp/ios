import Foundation
import EventKit

@MainActor
final class EventKitService {
    private let store = EKEventStore()

    var hasAccess: Bool {
        if #available(iOS 17, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// Returns upcoming events within the next 7 days, deduplicating recurring
    /// instances to only the next one per series.
    func upcomingEvents(within days: Int = 7) async -> [UpcomingEvent] {
        guard hasAccess else { return [] }
        let calendars = store.calendars(for: .event)
        let now = Date.now
        let end = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var seenSeries = Set<String>()
        var result: [UpcomingEvent] = []
        for event in events {
            // Skip past/all-day to keep the list relevant. All-day events skipped.
            if event.isAllDay { continue }
            if event.endDate <= now { continue }
            let seriesKey = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? UUID().uuidString
            if seenSeries.contains(seriesKey) { continue }
            seenSeries.insert(seriesKey)
            result.append(UpcomingEvent(from: event))
            if result.count >= 20 { break }
        }
        return result
    }
}
