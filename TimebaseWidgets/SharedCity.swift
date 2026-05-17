import Foundation

/// Lightweight City model for widgets — duplicates just enough of the host
/// app's City to render. Widgets load these from the shared App Group blob.
struct WidgetCity: Codable, Hashable, Identifiable {
    let name: String
    let country: String
    let tz: String
    let lat: Double
    let lon: Double

    var id: String { "\(name)|\(tz)" }
    var timeZone: TimeZone { TimeZone(identifier: tz) ?? .current }
}

/// Persisted struct shape matches `TimebaseStore.Persisted` — decode subset
/// of fields we need in the widget. Codable mirrors the host so the same
/// JSON blob written by the app is readable here.
struct WidgetPersisted: Codable {
    var cities: [WidgetCity]
    var homeCityId: String?
}

enum WidgetStore {
    static let appGroup = "group.cc.timebase.ios"
    static let storageKey = "timebase.v1"

    /// Reads the cities + home from the shared App Group.
    static func load() -> WidgetPersisted? {
        let defaults = UserDefaults(suiteName: appGroup)
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPersisted.self, from: data)
    }

    /// Default placeholder cities used when the App Group hasn't been
    /// written yet (e.g., immediately after install).
    static let placeholder: WidgetPersisted = .init(cities: [
        WidgetCity(name: "San Francisco", country: "United States", tz: "America/Los_Angeles",
                   lat: 37.77, lon: -122.42),
        WidgetCity(name: "New York", country: "United States", tz: "America/New_York",
                   lat: 40.71, lon: -74.00),
        WidgetCity(name: "London", country: "United Kingdom", tz: "Europe/London",
                   lat: 51.51, lon: -0.13),
        WidgetCity(name: "Tokyo", country: "Japan", tz: "Asia/Tokyo",
                   lat: 35.68, lon: 139.69),
        WidgetCity(name: "Sydney", country: "Australia", tz: "Australia/Sydney",
                   lat: -33.87, lon: 151.21),
    ], homeCityId: "San Francisco|America/Los_Angeles")
}
