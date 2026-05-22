import Foundation

/// The watchOS side of the Timebase iCloud key-value-store contract.
///
/// CONTRACT (must stay byte-compatible with iOS `CloudKVStore.swift`):
///  - `timebase.v1`        — one JSON blob: cities, homeCityId, settings,
///                           hasCompletedOnboarding (`TimebaseStore.Persisted`).
///  - `timebase.events.v1` — a `[EventSnapshot]` array the iPhone mirrors on
///                           every EventKit refresh (also lives in the App
///                           Group `UserDefaults`).
///
/// The Watch is **read-mostly**. It never writes `timebase.v1`. The one thing
/// it may write is the *currently focused city*, and that goes under a
/// SEPARATE key (`timebase.watch.focusedCity`) so it can never clobber the
/// shared blob.
///
/// If iOS ever changes the blob shape, the structs below must change in
/// lockstep — this file is the entire coupling surface.
enum KVSContract {
    static let appGroup = "group.cc.timebase.ios"
    static let blobKey = "timebase.v1"
    static let eventsKey = "timebase.events.v1"
    static let focusedCityKey = "timebase.watch.focusedCity"
}

/// The decoded subset of the `timebase.v1` blob the Watch needs.
///
/// `TimebaseStore.Persisted` on iOS is `{ cities, homeCityId, settings,
/// hasCompletedOnboarding }`. Decoding a subset is fine — exactly as the iOS
/// `WidgetPersisted` does for the widgets. `UserSettings` here decodes
/// leniently so unknown iOS-only keys are ignored.
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

/// Reads the Timebase shared state. Used by both the app and (via target
/// membership) the complications extension.
struct TimebaseSharedReader {

    private var ubiquitous: NSUbiquitousKeyValueStore { .default }
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: KVSContract.appGroup) }

    /// Reads the `timebase.v1` blob. Priority: iCloud KVS (cross-device,
    /// authoritative) -> App Group `UserDefaults` (last synced locally).
    func loadPersisted() -> PersistedSnapshot? {
        let data = ubiquitous.data(forKey: KVSContract.blobKey)
            ?? appGroupDefaults?.data(forKey: KVSContract.blobKey)
        guard let data else { return nil }
        return try? JSONDecoder().decode(PersistedSnapshot.self, from: data)
    }

    /// Reads the iPhone-mirrored event snapshot under `timebase.events.v1`.
    /// Returns only future events, soonest first. Empty when the snapshot is
    /// absent (no paired iPhone has written it).
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

    /// Whether the iPhone has ever mirrored an events snapshot. Used to
    /// decide between the no-prompt mirrored path and the standalone
    /// EventKit fallback.
    func hasMirroredEventsSnapshot() -> Bool {
        appGroupDefaults?.data(forKey: KVSContract.eventsKey) != nil
            || ubiquitous.data(forKey: KVSContract.eventsKey) != nil
    }

    /// Forces a KVS pull. iCloud KVS is push-based, but calling synchronize
    /// on launch / foreground gives the freshest local copy.
    func synchronize() {
        ubiquitous.synchronize()
    }

    /// Writes the currently focused city id under a DEDICATED key so iOS may
    /// optionally react. This never touches `timebase.v1`.
    func writeFocusedCity(_ cityId: String?) {
        if let cityId {
            ubiquitous.set(cityId, forKey: KVSContract.focusedCityKey)
        } else {
            ubiquitous.removeObject(forKey: KVSContract.focusedCityKey)
        }
        ubiquitous.synchronize()
    }

    /// Writes an updated city list into the shared `timebase.v1` blob,
    /// PRESERVING every other field by round-tripping the raw JSON object —
    /// the full `settings`, `hasCompletedOnboarding`, and any iOS-only key
    /// stay intact, so the Watch can never corrupt the iPhone's state. Writes
    /// to both iCloud KVS and the App Group so the app, widgets and
    /// complications all see the change.
    func writeCities(_ cities: [City], homeCityId: String?) {
        let existing = ubiquitous.data(forKey: KVSContract.blobKey)
            ?? appGroupDefaults?.data(forKey: KVSContract.blobKey)

        var object: [String: Any] = [:]
        if let existing,
           let parsed = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] {
            object = parsed
        }

        // Replace only the city fields; every other key is left untouched.
        if let citiesData = try? JSONEncoder().encode(cities),
           let citiesJSON = try? JSONSerialization.jsonObject(with: citiesData) {
            object["cities"] = citiesJSON
        }
        if let homeCityId {
            object["homeCityId"] = homeCityId
        } else {
            object.removeValue(forKey: "homeCityId")
        }
        // If the Watch is creating the blob from nothing, mark onboarding
        // done so a later iPhone install does not re-onboard over real data.
        if object["hasCompletedOnboarding"] == nil {
            object["hasCompletedOnboarding"] = true
        }

        guard let out = try? JSONSerialization.data(withJSONObject: object) else { return }
        ubiquitous.set(out, forKey: KVSContract.blobKey)
        appGroupDefaults?.set(out, forKey: KVSContract.blobKey)
        ubiquitous.synchronize()
    }
}
