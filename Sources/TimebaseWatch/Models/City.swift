import Foundation

/// A city in the world clock. Copied verbatim from the iOS `City` model —
/// a tiny `Codable` value type. The `Codable` representation must stay
/// byte-compatible with iOS so the `timebase.v1` KVS blob round-trips.
struct City: Identifiable, Hashable, Codable {
    var id: String { "\(name)|\(timezone)" }
    let name: String
    let country: String
    let timezone: String      // IANA, e.g. "America/New_York"
    let latitude: Double
    let longitude: Double
    let popular: Bool

    enum CodingKeys: String, CodingKey {
        case name, country
        case timezone = "tz"
        case latitude = "lat"
        case longitude = "lon"
        case popular
    }

    var timeZoneObject: TimeZone { TimeZone(identifier: timezone) ?? .current }
}

extension City {
    /// Loads the bundled cities.json (copied from iOS into the watch bundle).
    static func loadBundled() -> [City] {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([City].self, from: data)) ?? []
    }
}
