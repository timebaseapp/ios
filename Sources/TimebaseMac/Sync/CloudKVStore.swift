import Foundation

/// The Mac side of the Timebase iCloud key-value-store contract.
///
/// Byte-compatible with the iOS `CloudKVStore.swift`:
///  - `timebase.v1`        — one JSON blob: cities, homeCityId, settings,
///                           hasCompletedOnboarding (`Persisted` struct).
///  - `timebase.events.v1` — `[EventSnapshot]` the iPhone mirrors on every
///                           EventKit refresh, also in the App Group
///                           `UserDefaults`.
///
/// The Mac reads both; writes only when the user adds/removes a city or
/// records a Calendar event in the scheduler. Writes round-trip the raw JSON
/// so iOS-only fields (`autoRotateIcon`, `lastUserPickedIcon`,
/// `hasCompletedOnboarding`) are preserved byte-for-byte.
enum KVSContract {
    static let appGroup = "group.cc.timebase.ios"
    static let blobKey = "timebase.v1"
    static let eventsKey = "timebase.events.v1"
}

/// The decoded subset of the `timebase.v1` blob the Mac uses.
struct PersistedSnapshot: Codable {
    var cities: [City]
    var homeCityId: String?
    var settings: UserSettings

    enum CodingKeys: String, CodingKey {
        case cities, homeCityId, settings
    }

    init(cities: [City], homeCityId: String?, settings: UserSettings) {
        self.cities = cities
        self.homeCityId = homeCityId
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cities = (try? c.decode([City].self, forKey: .cities)) ?? []
        self.homeCityId = try? c.decodeIfPresent(String.self, forKey: .homeCityId)
        self.settings = (try? c.decode(UserSettings.self, forKey: .settings)) ?? UserSettings()
    }
}

/// Reads (and, when needed, writes) the Timebase shared state on macOS.
struct TimebaseSharedReader {

    private var ubiquitous: NSUbiquitousKeyValueStore { .default }
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: KVSContract.appGroup) }

    /// Reads the `timebase.v1` blob. Priority: iCloud KVS → App Group.
    func loadPersisted() -> PersistedSnapshot? {
        let data = ubiquitous.data(forKey: KVSContract.blobKey)
            ?? appGroupDefaults?.data(forKey: KVSContract.blobKey)
        guard let data else { return nil }
        return try? JSONDecoder().decode(PersistedSnapshot.self, from: data)
    }

    /// Reads the iPhone-mirrored event snapshot. Returns future events,
    /// soonest first.
    func loadMirroredEvents() -> [UpcomingEvent] {
        let data = appGroupDefaults?.data(forKey: KVSContract.eventsKey)
            ?? ubiquitous.data(forKey: KVSContract.eventsKey)
        guard let data,
              let events = try? JSONDecoder().decode([UpcomingEvent].self, from: data) else {
            return []
        }
        return events
            .filter { $0.endDate > Date() }
            .sorted { $0.startDate < $1.startDate }
    }

    func hasMirroredEventsSnapshot() -> Bool {
        appGroupDefaults?.data(forKey: KVSContract.eventsKey) != nil
            || ubiquitous.data(forKey: KVSContract.eventsKey) != nil
    }

    /// Force-pulls a fresh KVS copy.
    func synchronize() {
        ubiquitous.synchronize()
    }

    /// Writes an updated city list back into the shared `timebase.v1` blob,
    /// PRESERVING every other field by round-tripping the raw JSON object —
    /// `settings`, `hasCompletedOnboarding`, and any iOS-only key stay
    /// byte-for-byte intact, so the Mac cannot corrupt the iPhone's state.
    /// Writes to both iCloud KVS and the App Group.
    func writeCities(_ cities: [City], homeCityId: String?) {
        let existing = ubiquitous.data(forKey: KVSContract.blobKey)
            ?? appGroupDefaults?.data(forKey: KVSContract.blobKey)

        var object: [String: Any] = [:]
        if let existing,
           let parsed = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] {
            object = parsed
        }

        if let citiesData = try? JSONEncoder().encode(cities),
           let citiesJSON = try? JSONSerialization.jsonObject(with: citiesData) {
            object["cities"] = citiesJSON
        }
        if let homeCityId {
            object["homeCityId"] = homeCityId
        } else {
            object.removeValue(forKey: "homeCityId")
        }
        if object["hasCompletedOnboarding"] == nil {
            object["hasCompletedOnboarding"] = true
        }

        guard let out = try? JSONSerialization.data(withJSONObject: object) else { return }
        ubiquitous.set(out, forKey: KVSContract.blobKey)
        appGroupDefaults?.set(out, forKey: KVSContract.blobKey)
        ubiquitous.synchronize()
    }
}
