import Foundation
import SwiftUI
import Observation

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
    var scrubOffsetMinutes: Double = 0
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            scrubOffsetMinutes = 0
        }
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
