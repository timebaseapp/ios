import Foundation
import ActivityKit

/// Starts / ends a Live Activity for the soonest upcoming event, if it's
/// within the lead-time window (1 hour by default). Activities show on the
/// lock screen + Dynamic Island and tick down natively via
/// `Text(timerInterval:)`.
///
/// Each activity is created and then immediately handed a future dismissal
/// date (`event.endDate`) so the system removes it exactly when the event
/// is over — no background execution, no push server required. See
/// `startActivity` for the full reasoning.
@MainActor
enum EventCountdownActivityManager {
    private static let leadTime: TimeInterval = 60 * 60 // 1 hour

    /// Inspects the store's upcoming events and starts/ends a Live Activity
    /// to match. Idempotent — call after each EventKit refresh.
    static func sync(store: TimebaseStore) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        // Soonest event that hasn't ended yet AND starts within the lead
        // window (a currently-happening event also qualifies — its
        // time-to-start is negative).
        let candidate = store.upcomingEvents
            .filter { $0.endDate > now }
            .first { $0.startDate.timeIntervalSince(now) < leadTime }

        let current = Activity<EventCountdownAttributes>.activities.first

        switch (candidate, current) {
        case (nil, nil):
            return
        case (nil, let activity?):
            // Nothing in the window — clear any stale card still on screen.
            await activity.end(nil, dismissalPolicy: .immediate)
        case (let candidate?, nil):
            await startActivity(for: candidate, store: store)
        case (let candidate?, let activity?):
            // Is the on-screen activity already for this exact event? The
            // start instant + event timezone together identify it.
            let sameEvent =
                activity.content.state.start == candidate.startDate &&
                activity.attributes.eventTzIdentifier == candidate.timezone.identifier
            if !sameEvent {
                // The visible activity is for a different (likely passed)
                // event — swap it out.
                await activity.end(nil, dismissalPolicy: .immediate)
                await startActivity(for: candidate, store: store)
            }
            // If it IS the same event, leave it. The activity is staleDate-
            // marked at endDate, so the system styles it as stale once the
            // event is over; the next sync() call after endDate will end it.
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
    private static func startActivity(for event: UpcomingEvent, store: TimebaseStore) async {
        let homeTz = store.homeCity?.timeZoneObject ?? .current
        let attrs = EventCountdownAttributes(
            homeTzIdentifier: homeTz.identifier,
            eventTzIdentifier: event.timezone.identifier
        )
        let state = EventCountdownAttributes.ContentState(
            title: event.title,
            start: event.startDate
        )
        // staleDate at event.endDate lets the system render the card in its
        // "stale" style after the event is over. The activity stays
        // genuinely active until the next sync() call ends it — that's what
        // keeps the Dynamic Island showing it. Activities for past events
        // get cleaned up the next time the user foregrounds the app.
        let content = ActivityContent(state: state, staleDate: event.endDate)
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
