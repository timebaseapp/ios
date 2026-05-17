import Foundation
import SwiftUI
import Observation

enum ScreenTab: Int, Hashable {
    case upNextAbout = 0
    case clock = 1
    case settings = 2
}

enum Appearance: String, Codable, CaseIterable {
    case system, light, dark

    var preferred: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum HourPreference: String, Codable, CaseIterable {
    case system, on, off

    /// Returns explicit `is24Hour` or nil to follow the device locale.
    var is24Hour: Bool? {
        switch self {
        case .system: return nil
        case .on: return true
        case .off: return false
        }
    }
}

struct UserSettings: Codable {
    var hourPreference: HourPreference = .system
    var appearance: Appearance = .system
    var autoRotateIcon: Bool = false
}

@Observable
@MainActor
final class TimebaseStore {
    // MARK: - Persisted
    var cities: [City] = []
    var homeCityId: String?
    var settings = UserSettings()
    var hasCompletedOnboarding = false

    // MARK: - Transient
    /// Clamped to ±2 days. Beyond that, the time-of-day colors just repeat
    /// and the delta becomes meaningless.
    var scrubOffsetMinutes: Double = 0 {
        didSet {
            let bound = Self.scrubBoundMinutes
            if scrubOffsetMinutes > bound {
                scrubOffsetMinutes = bound
                if oldValue < bound { Haptics.scrubCapHit() }
            } else if scrubOffsetMinutes < -bound {
                scrubOffsetMinutes = -bound
                if oldValue > -bound { Haptics.scrubCapHit() }
            }
        }
    }

    static let scrubBoundMinutes: Double = 2 * 24 * 60

    /// Current page in the horizontal TabView.
    var currentTab: ScreenTab = .clock
    var upcomingEvents: [UpcomingEvent] = []
    var calendarAccessGranted = false

    // MARK: - Resources
    private(set) var cityDatabase: [City] = []
    private let calendarService = EventKitService()
    private let cloudStore = CloudKVStore()

    var upcomingEventsCount: Int {
        upcomingEvents.filter { $0.endDate > .now }.count
    }

    var homeCity: City? {
        cities.first(where: { $0.id == homeCityId }) ?? cities.first
    }

    /// All cities (including home) sorted by absolute UTC offset ascending —
    /// the colors should read as a continuous gradient. Home is marked
    /// separately via a 🏠 prefix on the row, not by position.
    var orderedCities: [City] {
        cities.sorted { a, b in
            let aOff = a.timeZoneObject.secondsFromGMT(for: displayDate)
            let bOff = b.timeZoneObject.secondsFromGMT(for: displayDate)
            if aOff == bOff { return a.name < b.name }
            return aOff < bOff
        }
    }

    /// The display "now" — real time plus the user's scrub offset.
    var displayDate: Date {
        Date().addingTimeInterval(scrubOffsetMinutes * 60)
    }

    // MARK: - Lifecycle

    @MainActor
    func bootstrap() async {
        cityDatabase = City.loadBundled()
        load()
        await refreshEvents()
    }

    // MARK: - Mutations

    func add(city: City) {
        guard !cities.contains(where: { $0.id == city.id }) else { return }
        cities.append(city)
        if homeCityId == nil { homeCityId = city.id }
        save()
    }

    func remove(cityId: String) {
        guard cities.count > 1 else { return }
        cities.removeAll { $0.id == cityId }
        if homeCityId == cityId { homeCityId = cities.first?.id }
        save()
    }

    func makeHome(cityId: String) {
        homeCityId = cityId
        save()
    }

    func reorder(from: IndexSet, to offset: Int) {
        cities.move(fromOffsets: from, toOffset: offset)
        save()
    }

    func snapToNow() {
        guard scrubOffsetMinutes != 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scrubOffsetMinutes = 0
        }
        Haptics.snapToNow()
    }

    func goTo(tab: ScreenTab) {
        guard currentTab != tab else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            currentTab = tab
        }
        Haptics.pageChanged()
    }

    func scrub(by deltaPixels: CGFloat) {
        let perPixel = 1.0 / 0.5 // pixels-per-minute reciprocal = minutes-per-pixel
        scrubOffsetMinutes += deltaPixels * perPixel
    }

    func setScrubOffset(_ minutes: Double) { scrubOffsetMinutes = minutes }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        save()
    }

    /// Returns the icon name corresponding to the time-of-day bucket at the
    /// user's home timezone (or device-current if no home set).
    func currentBucketIconName(at date: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = homeCity?.timeZoneObject ?? .current
        let h = cal.component(.hour, from: date)
        switch h {
        case 5..<11:  return "AppIcon-Morning"
        case 11..<15: return "AppIcon-Midday"
        case 15..<19: return "AppIcon-GoldenHour"
        default:      return "AppIcon-Dusk"
        }
    }

    /// Wipes everything: cities, home, settings, onboarding flag, scrub
    /// state. Clears both UserDefaults and iCloud KVS so a relaunch lands
    /// fresh on the onboarding flow.
    func resetAll() {
        cities = []
        homeCityId = nil
        settings = UserSettings()
        hasCompletedOnboarding = false
        scrubOffsetMinutes = 0
        upcomingEvents = []
        UserDefaults.standard.removeObject(forKey: "timebase.v1")
        cloudStore.clear()
    }

    // MARK: - Events / Calendar

    func requestCalendarAccess() async {
        calendarAccessGranted = await calendarService.requestAccess()
        await refreshEvents()
    }

    @MainActor
    func refreshEvents() async {
        guard calendarService.hasAccess else { return }
        upcomingEvents = await calendarService.upcomingEvents()
        calendarAccessGranted = true
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var cities: [City]
        var homeCityId: String?
        var settings: UserSettings
        var hasCompletedOnboarding: Bool
    }

    private func save() {
        let snapshot = Persisted(
            cities: cities, homeCityId: homeCityId,
            settings: settings, hasCompletedOnboarding: hasCompletedOnboarding
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: "timebase.v1")
        cloudStore.save(data)
    }

    private func load() {
        // Prefer iCloud KV if it has data; else fall back to UserDefaults.
        let data = cloudStore.load() ?? UserDefaults.standard.data(forKey: "timebase.v1")
        guard let data,
              let snapshot = try? JSONDecoder().decode(Persisted.self, from: data) else {
            return
        }
        self.cities = snapshot.cities
        self.homeCityId = snapshot.homeCityId
        self.settings = snapshot.settings
        self.hasCompletedOnboarding = snapshot.hasCompletedOnboarding
    }

    func seedDefaultsIfEmpty(localTimezone: TimeZone = .current) {
        guard cities.isEmpty else { return }
        let db = cityDatabase
        let homeMatch = db.first(where: { $0.timezone == localTimezone.identifier })
                     ?? db.first(where: { $0.name == "San Francisco" })
        var seeds: [City] = []
        if let homeMatch { seeds.append(homeMatch) }
        for name in ["New York", "London", "Tokyo"] {
            if let c = db.first(where: { $0.name == name }), !seeds.contains(where: { $0.id == c.id }) {
                seeds.append(c)
            }
        }
        cities = seeds
        homeCityId = seeds.first?.id
        save()
    }
}
