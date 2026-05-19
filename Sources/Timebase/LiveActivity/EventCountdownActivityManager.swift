import Foundation
import ActivityKit

/// Starts / updates / ends a Live Activity for the soonest upcoming event,
/// if it's within the lead-time window (1 hour by default). Activities show
/// on the lock screen + Dynamic Island and tick down natively via
/// `Text(timerInterval:)`.
@MainActor
enum EventCountdownActivityManager {
    private static let leadTime: TimeInterval = 60 * 60 // 1 hour

    /// Inspects the store's upcoming events and starts/updates/ends a Live
    /// Activity to match. Idempotent — call after each EventKit refresh.
    static func sync(store: TimebaseStore) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let candidate = store.upcomingEvents.first(where: {
            $0.startDate > now &&
            $0.startDate.timeIntervalSince(now) < leadTime
        })
        let current = Activity<EventCountdownAttributes>.activities.first

        switch (candidate, current) {
        case (nil, nil):
            return
        case (nil, let activity?):
            await activity.end(nil, dismissalPolicy: .immediate)
        case (let candidate?, nil):
            startActivity(for: candidate, store: store)
        case (let candidate?, let activity?):
            if activity.attributes.eventTzIdentifier == candidate.timezone.identifier {
                let state = EventCountdownAttributes.ContentState(
                    title: candidate.title,
                    start: candidate.startDate
                )
                await activity.update(ActivityContent(state: state, staleDate: candidate.startDate))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
                startActivity(for: candidate, store: store)
            }
        }
    }

    /// Ends every active EventCountdown Live Activity immediately. Used
    /// by resetAll to clear stale lock-screen cards after a wipe.
    static func endAll() async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<EventCountdownAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.2, *)
    private static func startActivity(for event: UpcomingEvent, store: TimebaseStore) {
        let homeTz = store.homeCity?.timeZoneObject ?? .current
        let attrs = EventCountdownAttributes(
            homeTzIdentifier: homeTz.identifier,
            eventTzIdentifier: event.timezone.identifier
        )
        let state = EventCountdownAttributes.ContentState(
            title: event.title,
            start: event.startDate
        )
        let content = ActivityContent(state: state, staleDate: event.startDate)
        do {
            _ = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity start failed: \(error.localizedDescription)")
            #endif
        }
    }
}
