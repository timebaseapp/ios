import Foundation
import EventKit

/// Carries a non-Sendable value across a concurrency boundary — used only to
/// hand a freshly-built EKEventStore back from a background task. EKEventStore
/// is safe to create off-thread and use anywhere; it's just not annotated
/// `Sendable`.
private struct SendableBox<T>: @unchecked Sendable { let value: T }

@MainActor
final class EventKitService {
    /// One service — and one EKEventStore — for the whole app; Apple
    /// recommends a single store for an app's lifetime.
    static let shared = EventKitService()
    private init() {}

    private var _store: EKEventStore?

    /// The app's EKEventStore. `EKEventStore()`'s initializer opens the
    /// Calendar database from disk, so `warmUp()` builds it ahead of time on
    /// a background thread and this getter then just returns the cached
    /// instance. The on-demand path is a fallback for the (practically
    /// impossible) case of a call before warm-up finishes.
    var store: EKEventStore {
        if let s = _store { return s }
        let s = EKEventStore()
        _store = s
        return s
    }

    /// Pre-builds the EKEventStore off the main thread. Call once, early
    /// (from `TimebaseStore.bootstrap()`).
    func warmUp() async {
        guard _store == nil else { return }
        let built = await Task.detached(priority: .userInitiated) {
            SendableBox(value: EKEventStore())
        }.value
        if _store == nil { _store = built.value }
    }

    var hasAccess: Bool {
        if #available(iOS 17, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    /// The default calendar new events save into. Apple's EKEventEditView uses
    /// this by default; we expose it for our own scheduler flow.
    var defaultCalendar: EKCalendar? {
        store.defaultCalendarForNewEvents
    }

    /// Build a fresh EKEvent ready to hand to EKEventEditViewController.
    func makeDraftEvent(title: String, start: Date, end: Date) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.calendar = defaultCalendar
        return event
    }

    /// Save an event directly (without presenting the editor). Used if a
    /// future "quick save" path appears; current flow uses EKEventEditView.
    func save(event: EKEvent) throws {
        try store.save(event, span: .thisEvent, commit: true)
    }

    /// Fetch a fresh EKEvent by its identifier — gives us everything
    /// (location, notes, attendees, calendar, recurrence) the lightweight
    /// `UpcomingEvent` projection doesn't carry.
    func event(withIdentifier id: String) -> EKEvent? {
        store.event(withIdentifier: id)
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
