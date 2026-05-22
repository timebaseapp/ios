import WidgetKit
import Foundation

/// Timeline entry carrying the synced cities + events. The provider reads the
/// same `timebase.v1` / `timebase.events.v1` App Group blobs the app reads,
/// and emits minute-spaced entries — the pattern the iOS widgets use.
struct TimebaseEntry: TimelineEntry {
    let date: Date
    let cities: [City]
    let homeCityId: String?
    let settings: UserSettings
    let events: [UpcomingEvent]

    var homeCity: City? {
        cities.first(where: { $0.id == homeCityId }) ?? cities.first
    }

    /// Cities ordered by UTC offset ascending — same rule as the app.
    var orderedCities: [City] {
        cities.sorted { a, b in
            let aOff = a.timeZoneObject.secondsFromGMT(for: date)
            let bOff = b.timeZoneObject.secondsFromGMT(for: date)
            if aOff == bOff { return a.name < b.name }
            return aOff < bOff
        }
    }

    /// The soonest still-future event.
    var nextEvent: UpcomingEvent? {
        events.filter { $0.endDate > date }.sorted { $0.startDate < $1.startDate }.first
    }
}

/// Shared timeline provider for every Timebase complication family.
struct TimebaseProvider: TimelineProvider {
    private let reader = TimebaseSharedReader()

    func placeholder(in context: Context) -> TimebaseEntry {
        Self.placeholderEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (TimebaseEntry) -> Void) {
        reader.synchronize()
        completion(currentEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimebaseEntry>) -> Void) {
        reader.synchronize()
        let snapshot = reader.loadPersisted()
        let events = reader.loadMirroredEvents()
        let cal = Calendar.current
        let base = cal.date(bySetting: .second, value: 0, of: .now) ?? .now

        // One entry per minute for the next 60 minutes — the dial color and
        // countdowns stay live without explicit reloads.
        var entries: [TimebaseEntry] = []
        for i in 0 ..< 60 {
            guard let d = cal.date(byAdding: .minute, value: i, to: base) else { continue }
            entries.append(TimebaseEntry(
                date: d,
                cities: snapshot?.cities ?? Self.placeholderEntry.cities,
                homeCityId: snapshot?.homeCityId ?? Self.placeholderEntry.homeCityId,
                settings: snapshot?.settings ?? UserSettings(),
                events: events
            ))
        }
        let next = cal.date(byAdding: .minute, value: 60, to: base) ?? .now
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func currentEntry(at date: Date) -> TimebaseEntry {
        let snapshot = reader.loadPersisted()
        return TimebaseEntry(
            date: date,
            cities: snapshot?.cities ?? Self.placeholderEntry.cities,
            homeCityId: snapshot?.homeCityId ?? Self.placeholderEntry.homeCityId,
            settings: snapshot?.settings ?? UserSettings(),
            events: reader.loadMirroredEvents()
        )
    }

    /// Used before the App Group blob exists (preview / fresh install).
    static let placeholderEntry: TimebaseEntry = {
        let cities = [
            City(name: "San Francisco", country: "United States",
                 timezone: "America/Los_Angeles", latitude: 37.77, longitude: -122.42, popular: true),
            City(name: "London", country: "United Kingdom",
                 timezone: "Europe/London", latitude: 51.51, longitude: -0.13, popular: true),
            City(name: "Tokyo", country: "Japan",
                 timezone: "Asia/Tokyo", latitude: 35.68, longitude: 139.69, popular: true),
        ]
        return TimebaseEntry(
            date: .now,
            cities: cities,
            homeCityId: cities.first?.id,
            settings: UserSettings(),
            events: [
                UpcomingEvent(id: "ph-1", title: "Standup",
                              startDate: .now.addingTimeInterval(900),
                              endDate: .now.addingTimeInterval(2700),
                              timezoneIdentifier: TimeZone.current.identifier)
            ]
        )
    }()
}
