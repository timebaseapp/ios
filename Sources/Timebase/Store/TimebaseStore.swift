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

    /// Trips when a deep link wants the scheduler to open. UpNextScreen
    /// watches this and presents `SchedulerSheet`, then resets the flag.
    var pendingShowScheduler = false

    /// Triggered when the easter-egg quick action fires. Briefly shows a
    /// time-of-day greeting overlay.
    var greeting: String?
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

    /// Cap on the world-clock list. Beyond this the rows get too short to
    /// read and start fighting the dynamic island.
    static let maxCities = 8

    var isAtCityCap: Bool { cities.count >= Self.maxCities }

    func add(city: City) {
        guard !cities.contains(where: { $0.id == city.id }) else { return }
        guard cities.count < Self.maxCities else { return }
        cities.append(city)
        if homeCityId == nil { homeCityId = city.id }
        save()
    }

    /// Picks the city closest to the given coordinates from the bundled
    /// database, adds it if not present, and marks it as home. Called from
    /// Onboarding when location permission is granted.
    func setHomeFromCoordinates(latitude: Double, longitude: Double) {
        let closest = cityDatabase.min { a, b in
            haversineDistance(lat1: latitude, lon1: longitude, lat2: a.latitude, lon2: a.longitude) <
            haversineDistance(lat1: latitude, lon1: longitude, lat2: b.latitude, lon2: b.longitude)
        }
        guard let closest else { return }
        if !cities.contains(where: { $0.id == closest.id }) {
            if cities.count >= Self.maxCities {
                cities.removeFirst()
            }
            cities.insert(closest, at: 0)
        }
        homeCityId = closest.id
        save()
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let toRad = { (d: Double) in d * .pi / 180 }
        let dLat = toRad(lat2 - lat1)
        let dLon = toRad(lon2 - lon1)
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon/2) * sin(dLon/2)
        return R * 2 * asin(sqrt(a))
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
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        Self.sharedDefaults.removeObject(forKey: Self.storageKey)
        cloudStore.clear()
        WidgetReload.requestAllTimelinesReload()
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
        await EventCountdownActivityManager.sync(store: self)
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var cities: [City]
        var homeCityId: String?
        var settings: UserSettings
        var hasCompletedOnboarding: Bool
    }

    /// Persisted state lives in an App Group container so extensions
    /// (widgets, Live Activities, control center) can read the same blob.
    static let appGroup = "group.cc.timebase.ios"
    static let storageKey = "timebase.v1"
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private func save() {
        let snapshot = Persisted(
            cities: cities, homeCityId: homeCityId,
            settings: settings, hasCompletedOnboarding: hasCompletedOnboarding
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        Self.sharedDefaults.set(data, forKey: Self.storageKey)
        // Mirror to standard defaults for backward compat with older installs.
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        cloudStore.save(data)
        // Tell widgets to refresh their timelines.
        WidgetReload.requestAllTimelinesReload()
    }

    private func load() {
        // Priority: iCloud KV (cross-device) → App Group → UserDefaults
        // (legacy install).
        let data = cloudStore.load()
            ?? Self.sharedDefaults.data(forKey: Self.storageKey)
            ?? UserDefaults.standard.data(forKey: Self.storageKey)
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
