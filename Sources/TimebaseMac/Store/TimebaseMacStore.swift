import Foundation
import SwiftUI
import Observation

/// Central macOS store — Mac's own bespoke `@Observable @MainActor` source of
/// truth. Mirrors the *shape* of the iOS store but is its own code, tuned for
/// the menubar + window + scheduler + widget surfaces.
@Observable
@MainActor
final class TimebaseMacStore {

    // MARK: - Synced state (from `timebase.v1`)
    var cities: [City] = []
    var homeCityId: String?
    var settings = UserSettings()

    // MARK: - Mirrored events (from `timebase.events.v1`)
    var upcomingEvents: [UpcomingEvent] = []

    // MARK: - Mac-local menubar selection
    //
    // The wearer chooses up to four cities for the menubar popover. Stored
    // in the Mac's own `UserDefaults` — never written to `timebase.v1` —
    // so it's a Mac-local preference, not a synced one.

    var menubarCityIds: [String] = [] {
        didSet {
            UserDefaults.standard.set(menubarCityIds, forKey: Self.menubarCityIdsKey)
        }
    }

    private static let menubarCityIdsKey = "macos.menubarCityIds"

    /// Maximum cities pinned to the menubar popover. The popover stays calm
    /// when crowded — four rows is the right shape.
    static let menubarCityCap = 4

    /// The cities the menubar should show — the wearer's pinned selection if
    /// set, otherwise home + first 3 non-home cities by UTC offset. Always
    /// includes home when home exists.
    var menubarCities: [City] {
        let byId = Dictionary(uniqueKeysWithValues: cities.map { ($0.id, $0) })
        return effectiveMenubarCityIds.compactMap { byId[$0] }
    }

    /// The IDs the menubar is *effectively* showing — the stored array if the
    /// wearer has customized, otherwise the implicit default (home + first 3
    /// non-home by tz). This is what the customize sheet should read so
    /// checkboxes reflect what's actually on screen.
    var effectiveMenubarCityIds: [String] {
        if !menubarCityIds.isEmpty {
            // Stored selection wins, capped at menubarCityCap. Home is always
            // first if present.
            var out: [String] = []
            if let homeId = homeCityId, cities.contains(where: { $0.id == homeId }) {
                out.append(homeId)
            }
            for id in menubarCityIds where id != homeCityId {
                if out.count >= Self.menubarCityCap { break }
                if cities.contains(where: { $0.id == id }) {
                    out.append(id)
                }
            }
            return out
        }
        // Default: home + first 3 non-home by tz, capped at menubarCityCap.
        let ordered = tzSorted(cities)
        var out: [String] = []
        if let home = ordered.first(where: { $0.id == homeCityId }) {
            out.append(home.id)
        }
        for c in ordered where c.id != homeCityId {
            if out.count >= Self.menubarCityCap { break }
            out.append(c.id)
        }
        return out
    }

    // MARK: - Scrub state (for the main window)
    //
    // Same clamp + 5-minute snap math as iOS. The menubar doesn't scrub, but
    // the main window does; the store owns the state so any surface can
    // observe it.

    var scrubOffsetMinutes: Double = 0 {
        didSet {
            let bound = Self.scrubBoundMinutes
            if scrubOffsetMinutes > bound {
                scrubOffsetMinutes = bound
                return
            } else if scrubOffsetMinutes < -bound {
                scrubOffsetMinutes = -bound
                return
            }
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

    static let scrubBoundMinutes: Double = 2 * 24 * 60

    // MARK: - Derived

    var displayDate: Date {
        Date().addingTimeInterval(scrubOffsetMinutes * 60)
    }

    var homeCity: City? {
        cities.first(where: { $0.id == homeCityId }) ?? cities.first
    }

    var homeTimeZone: TimeZone {
        homeCity?.timeZoneObject ?? .current
    }

    /// All cities ordered by UTC offset ascending (the iOS ordering rule).
    var orderedCities: [City] {
        tzSorted(cities)
    }

    /// The soonest still-future event, if any.
    var nextEvent: UpcomingEvent? {
        upcomingEvents.first { $0.endDate > Date() }
    }

    /// Delta-from-home label for a city — `+5h 30m`, `−2h 30m`, or `Home`.
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

    private func tzSorted(_ list: [City]) -> [City] {
        list.sorted { a, b in
            let aOff = a.timeZoneObject.secondsFromGMT(for: displayDate)
            let bOff = b.timeZoneObject.secondsFromGMT(for: displayDate)
            if aOff == bOff { return a.name < b.name }
            return aOff < bOff
        }
    }

    // MARK: - Resources
    private let reader = TimebaseSharedReader()

    // MARK: - Lifecycle

    init() {
        if let arr = UserDefaults.standard.array(forKey: Self.menubarCityIdsKey) as? [String] {
            menubarCityIds = arr
        }
    }

    /// Loads the synced state and the mirrored events. Called on launch and
    /// on app activation.
    func bootstrap() {
        reader.synchronize()
        loadPersisted()
        seedDefaultsIfEmpty()
        loadEvents()
    }

    func loadPersisted() {
        guard let snapshot = reader.loadPersisted() else { return }
        cities = snapshot.cities
        homeCityId = snapshot.homeCityId
        settings = snapshot.settings
    }

    func loadEvents() {
        let mirrored = reader.loadMirroredEvents()
        upcomingEvents = mirrored

        #if DEBUG
        // No paired iPhone in the dev cycle — seed a few events so the
        // menubar and floating panel are visible. Never compiled into release.
        if upcomingEvents.isEmpty {
            upcomingEvents = Self.sampleEvents()
        }
        #endif
    }

    /// When no synced blob is available — a fresh install or first launch
    /// before iCloud syncs — seed default cities so the menubar is never
    /// blank. Mirrors the iOS `seedDefaultsIfEmpty`. In-memory until the
    /// scheduler (later) writes a real blob.
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

    // MARK: - Menubar selection

    /// Updates the wearer's pinned menubar city ids (max four), preserving
    /// order. Empty array restores the default (home + first 3 by tz).
    func setMenubarCityIds(_ ids: [String]) {
        let capped = Array(ids.prefix(Self.menubarCityCap))
        menubarCityIds = capped
    }

    /// Whether a city is *effectively* shown in the menubar — reads from the
    /// effective set, not the raw stored array. Reflects what's on screen.
    func isMenubarCityPinned(_ id: String) -> Bool {
        effectiveMenubarCityIds.contains(id)
    }

    /// Toggles a city's presence in the menubar. Materializes the implicit
    /// default into the stored array on first edit so the change reads as
    /// the wearer expects: checking/unchecking starts from what's already
    /// on screen, not from an empty list.
    func toggleMenubarCity(_ id: String) {
        guard id != homeCityId else { return }
        var current = menubarCityIds.isEmpty ? effectiveMenubarCityIds : menubarCityIds
        if current.contains(id) {
            current.removeAll { $0 == id }
        } else {
            // Home occupies one slot implicitly when present.
            let cap = Self.menubarCityCap
            if current.count >= cap { return }
            current.append(id)
        }
        menubarCityIds = current
    }

    // MARK: - Scrub

    func snapToNow() {
        guard scrubOffsetMinutes != 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scrubOffsetMinutes = 0
        }
    }

    #if DEBUG
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
}
