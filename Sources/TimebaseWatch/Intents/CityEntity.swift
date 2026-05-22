import Foundation
import AppIntents

/// AppEntity representing a city — queried by name from the bundled
/// `cities.json` so Siri / Shortcuts on the Watch can pick one. Copied from
/// the iOS `CityEntity`; the query reads the same bundled database.
struct CityEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "City")

    static let defaultQuery = CityQuery()

    var id: String
    var name: String
    var country: String
    var timezone: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(country)")
    }

    init(from city: City) {
        self.id = city.id
        self.name = city.name
        self.country = city.country
        self.timezone = city.timezone
    }
}

struct CityQuery: EntityStringQuery {
    func entities(for identifiers: [CityEntity.ID]) async throws -> [CityEntity] {
        City.loadBundled()
            .filter { identifiers.contains($0.id) }
            .map(CityEntity.init)
    }

    func entities(matching string: String) async throws -> [CityEntity] {
        let q = string.lowercased()
        return City.loadBundled()
            .filter { $0.name.lowercased().contains(q) || $0.country.lowercased().contains(q) }
            .prefix(25)
            .map(CityEntity.init)
    }

    func suggestedEntities() async throws -> [CityEntity] {
        City.loadBundled()
            .filter(\.popular)
            .prefix(15)
            .map(CityEntity.init)
    }
}
