import Foundation
import SwiftUI
import Observation
import WatchKit

/// Which screen the wrist is currently looking at — for deep links.
enum WatchRoute: Equatable {
    case clock(cityId: String?)
    case upNext
}

/// The source the Up Next list is currently drawing from.
enum EventSource: Equatable {
    /// The iPhone-mirrored snapshot (`timebase.events.v1`). No prompt.
    case mirrored
    /// Direct Watch-side EventKit (the opt-in standalone fallback).
    case directEventKit
    /// No events available from either path yet.
    case none
}

/// Central watch store — the trimmed wrist counterpart to the iOS
/// `TimebaseStore`. `@Observable @MainActor`, exactly as the SCOPE specifies.
@Observable
@MainActor
final class TimebaseWatchStore {

    // MARK: - Persisted mirror (read-only on the Watch)
    var cities: [City] = []
    var homeCityId: String?
    var settings = UserSettings()

    // MARK: - Watch-local preferences
    //
    // These display preferences live in the Watch's own `UserDefaults` — they
    // tune the wrist without touching the shared `timebase.v1` blob. (City
    // changes do write that blob — see City management below.)

    /// Watch-local 24-hour override. `nil` follows the iPhone-synced value.
    var hourPreferenceOverride: HourPreference? {
        didSet {
            if let raw = hourPreferenceOverride?.rawValue {
                UserDefaults.standard.set(raw, forKey: Self.hourOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.hourOverrideKey)
            }
        }
    }

    private static let hourOverrideKey = "timebase.watch.hourOverride"

    /// The 24-hour preference the Watch actually displays.
    var effectiveHourPreference: HourPreference {
        hourPreferenceOverride ?? settings.hourPreference
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.hourOverrideKey) {
            hourPreferenceOverride = HourPreference(rawValue: raw)
        }
    }

    // MARK: - Events
    var upcomingEvents: [UpcomingEvent] = []
    var eventSource: EventSource = .none
    /// True once the user has granted Watch-side calendar access.
    var calendarAccessGranted = false

    // MARK: - Navigation
    /// Set by a `timebase://` deep link (complication tap). `RootView`
    /// observes it, navigates, then clears it.
    var pendingRoute: WatchRoute?

    // MARK: - Transient scrub state
    /// Clamped to ±2 days. Beyond that the colors just repeat. Mutating this
    /// runs the same clamp + snap-to-5-minute logic the iOS store has, so the
    /// scrub pill shows identical numbers.
    var scrubOffsetMinutes: Double = 0 {
        didSet {
            let bound = Self.scrubBoundMinutes
            if scrubOffsetMinutes > bound {
                scrubOffsetMinutes = bound
                if oldValue < bound { WatchHaptics.scrubCap() }
                return
            } else if scrubOffsetMinutes < -bound {
                scrubOffsetMinutes = -bound
                if oldValue > -bound { WatchHaptics.scrubCap() }
                return
            }
            // Snap the *displayed wall-clock minute* to the nearest 5 — same
            // reference-date math as iOS. Every named tz offset is a multiple
            // of 15 min, so a UTC 5-min boundary is a 5-min boundary locally.
            if scrubOffsetMinutes != 0 {
                let real = Date()
                let target = real.addingTimeInterval(scrubOffsetMinutes * 60)
                let snappedAbs = (target.timeIntervalSinceReferenceDate / 300).rounded() * 300
                let snappedDate = Date(timeIntervalSinceReferenceDate: snappedAbs)
                let snappedOffset = snappedDate.timeIntervalSince(real) / 60
                if abs(snappedOffset - scrubOffsetMinutes) > 0.05 {
                    scrubOffsetMinutes = snappedOffset
                }
            }
        }
    }

    /// ±2 days, identical to the iOS `scrubBoundMinutes`.
    static let scrubBoundMinutes: Double = 2 * 24 * 60

    // MARK: - Derived

    /// The display "now" — real time plus the scrub offset.
    var displayDate: Date {
        Date().addingTimeInterval(scrubOffsetMinutes * 60)
    }

    var homeCity: City? {
        cities.first(where: { $0.id == homeCityId }) ?? cities.first
    }

    /// The cities on the Watch world clock — at most four. The Watch is a
    /// glance device: four cities fill the screen with no scrolling, and the
    /// full set lives on iPhone. Sorted by UTC offset so the bands read as a
    /// continuous sweep of color; the home city is always among the four.
    var orderedCities: [City] {
        let sorted = tzSorted(cities)
        guard sorted.count > Self.maxCities else { return sorted }
        var top = Array(sorted.prefix(Self.maxCities))
        if let homeId = homeCityId,
           !top.contains(where: { $0.id == homeId }),
           let home = sorted.first(where: { $0.id == homeId }) {
            top[top.count - 1] = home
            top = tzSorted(top)
        }
        return top
    }

    /// Sorts cities by UTC offset ascending, name as the tiebreaker.
    private func tzSorted(_ list: [City]) -> [City] {
        list.sorted { a, b in
            let aOff = a.timeZoneObject.secondsFromGMT(for: displayDate)
            let bOff = b.timeZoneObject.secondsFromGMT(for: displayDate)
            if aOff == bOff { return a.name < b.name }
            return aOff < bOff
        }
    }

    var homeTimeZone: TimeZone {
        homeCity?.timeZoneObject ?? .current
    }

    // MARK: - Resources
    private let reader = TimebaseSharedReader()
    private let calendarService = WatchCalendarService()

    // MARK: - Lifecycle

    /// Loads the synced state and the best available event source. Called on
    /// launch and on foreground.
    func bootstrap() {
        reader.synchronize()
        loadPersisted()
        seedDefaultsIfEmpty()
        loadEvents()
    }

    /// When no synced `timebase.v1` blob is available — a genuinely standalone
    /// Watch, or a first launch before iCloud has synced — fall back to a
    /// default set of cities so the world clock is never blank. The seeds
    /// stay in memory until the wearer first adds or removes a city (which
    /// persists the list); a `loadPersisted()` with real synced cities
    /// overrides them first. Mirrors the iOS `seedDefaultsIfEmpty`.
    func seedDefaultsIfEmpty(localTimeZone: TimeZone = .current) {
        guard cities.isEmpty else { return }
        let db = City.loadBundled()
        let homeMatch = db.first(where: { $0.timezone == localTimeZone.identifier })
                     ?? db.first(where: { $0.name == "San Francisco" })
        var seeds: [City] = []
        if let homeMatch { seeds.append(homeMatch) }
        for name in ["New York", "London", "Tokyo"] {
            if let c = db.first(where: { $0.name == name }),
               !seeds.contains(where: { $0.id == c.id }) {
                seeds.append(c)
            }
        }
        cities = seeds
        homeCityId = seeds.first?.id
    }

    /// Re-reads the `timebase.v1` blob into the store.
    func loadPersisted() {
        guard let snapshot = reader.loadPersisted() else { return }
        cities = snapshot.cities
        homeCityId = snapshot.homeCityId
        settings = snapshot.settings
    }

    // MARK: - City management
    //
    // Adding or removing a city writes the shared `timebase.v1` blob, so the
    // change syncs to iPhone and every device. `CloudKVStore.writeCities`
    // round-trips the raw JSON, leaving every iOS-only field intact.

    /// The Watch shows at most four cities — a deliberate glance limit. The
    /// iPhone keeps the larger list (its own cap is higher).
    static let maxCities = 4

    var isAtCityCap: Bool { cities.count >= Self.maxCities }

    /// Adds a city and persists the new list to iCloud.
    func addCity(_ city: City) {
        guard !isAtCityCap else { return }
        guard !cities.contains(where: { $0.id == city.id }) else { return }
        cities.append(city)
        if homeCityId == nil { homeCityId = city.id }
        reader.writeCities(cities, homeCityId: homeCityId)
    }

    /// Removes a city and persists the new list. Home cannot be removed.
    func removeCity(_ id: String) {
        guard id != homeCityId else { return }
        cities.removeAll { $0.id == id }
        reader.writeCities(cities, homeCityId: homeCityId)
    }

    /// Picks the best event source: the iPhone-mirrored snapshot wins when
    /// present (it is the iPhone's authoritative refresh); direct EventKit is
    /// used only when access was already granted on this Watch.
    func loadEvents() {
        let mirrored = reader.loadMirroredEvents()
        if !mirrored.isEmpty || reader.hasMirroredEventsSnapshot() {
            upcomingEvents = Array(mirrored.prefix(20))
            eventSource = .mirrored
        } else if calendarService.hasAccess {
            calendarAccessGranted = true
            upcomingEvents = calendarService.upcomingEvents()
            eventSource = .directEventKit
        } else {
            upcomingEvents = []
            eventSource = .none
        }

        #if DEBUG
        // The Watch Simulator has no paired iPhone and no calendar, so Up
        // Next would always be empty. Seed sample events so the screen can
        // be seen during development. Never compiled into a release build.
        if upcomingEvents.isEmpty {
            upcomingEvents = Self.sampleEvents()
            eventSource = .mirrored
        }
        #endif
    }

    #if DEBUG
    /// Sample events for the Simulator — DEBUG only, never ships.
    static func sampleEvents() -> [UpcomingEvent] {
        let now = Date()
        let local = TimeZone.current.identifier
        func event(_ id: String, _ title: String,
                   inMinutes start: Double, lasting: Double,
                   tz: String) -> UpcomingEvent {
            UpcomingEvent(id: id, title: title,
                          startDate: now.addingTimeInterval(start * 60),
                          endDate: now.addingTimeInterval((start + lasting) * 60),
                          timezoneIdentifier: tz)
        }
        return [
            event("sample-1", "Morning standup", inMinutes: 23, lasting: 30, tz: local),
            event("sample-2", "Design review", inMinutes: 162, lasting: 60, tz: local),
            event("sample-3", "Call with the Tokyo team",
                  inMinutes: 372, lasting: 45, tz: "Asia/Tokyo"),
        ]
    }
    #endif

    /// True when the Watch should offer the opt-in "Show my events" action —
    /// i.e. no mirrored snapshot exists and Watch calendar access is not yet
    /// granted.
    var shouldOfferStandaloneCalendar: Bool {
        !reader.hasMirroredEventsSnapshot() && !calendarService.hasAccess
    }

    /// The top 3 upcoming events for the Up Next screen.
    var nextThreeEvents: [UpcomingEvent] {
        Array(upcomingEvents.filter { $0.endDate > Date() }.prefix(3))
    }

    // MARK: - Standalone EventKit fallback

    /// Requests Watch-side calendar access (a separate system prompt) and,
    /// when granted, switches Up Next to the direct EventKit source.
    func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        calendarAccessGranted = granted
        if granted {
            upcomingEvents = calendarService.upcomingEvents()
            eventSource = .directEventKit
        }
    }

    // MARK: - Scrub

    /// Snap back to now with a spring + confirming haptic — the iOS
    /// `snapToNow` behavior.
    func snapToNow() {
        guard scrubOffsetMinutes != 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scrubOffsetMinutes = 0
        }
        WatchHaptics.snapToNow()
    }

    // MARK: - Focused city write (the one allowed KVS write)

    /// Records which city page the wearer last looked at, under a DEDICATED
    /// KVS key — never touches `timebase.v1`.
    func setFocusedCity(_ cityId: String?) {
        reader.writeFocusedCity(cityId)
    }

    // MARK: - Formatting

    /// The scrub-delta string for the pill — `+3h`, `−1d 4h`. Identical
    /// formatting to the iOS scrub pill.
    func scrubDeltaText() -> String {
        let minutes = Int(scrubOffsetMinutes.rounded())
        let sign = minutes >= 0 ? "+" : "−"
        let abs = Swift.abs(minutes)
        let days = abs / 1440
        let hours = (abs % 1440) / 60
        let mins = abs % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if mins > 0 && days == 0 { parts.append("\(mins)m") }
        if parts.isEmpty { parts.append("0m") }
        return "\(sign)\(parts.joined(separator: " "))"
    }

    /// Delta-from-home label for a city card — `+5h 30m`, `−2h 30m`, or the
    /// literal word `Home` for the home city.
    func deltaLabel(for city: City) -> String {
        if city.id == homeCityId { return "Home" }
        let date = displayDate
        let cityOff = city.timeZoneObject.secondsFromGMT(for: date)
        let homeOff = homeTimeZone.secondsFromGMT(for: date)
        let deltaSeconds = cityOff - homeOff
        if deltaSeconds == 0 { return "±0h" }
        let sign = deltaSeconds > 0 ? "+" : "−"
        let abs = Swift.abs(deltaSeconds)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        return m > 0 ? "\(sign)\(h)h \(m)m" : "\(sign)\(h)h"
    }
}
