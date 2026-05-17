import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Surfaces the user's cities in iOS Spotlight. Typing "Tokyo" in Spotlight
/// returns a Timebase entry showing the current local time; tapping it
/// deep-links into the app at that city's detail.
@MainActor
enum SpotlightIndexer {
    private static let domainID = "cc.timebase.cities"

    /// Re-index all current cities. Cheap enough to run on every launch +
    /// after city add / remove.
    static func reindex(cities: [City]) async {
        let items = cities.map { item(for: $0) }
        do {
            try await CSSearchableIndex.default()
                .deleteSearchableItems(withDomainIdentifiers: [domainID])
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            #if DEBUG
            print("Spotlight index error: \(error.localizedDescription)")
            #endif
        }
    }

    private static func item(for city: City) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = "\(city.name) · time"
        attrs.contentDescription = "\(city.country) — current time in Timebase"
        attrs.keywords = [city.name, city.country, "time", "timezone", "clock", city.timezone]
        attrs.relatedUniqueIdentifier = city.id

        let item = CSSearchableItem(
            uniqueIdentifier: city.id,
            domainIdentifier: domainID,
            attributeSet: attrs
        )
        return item
    }
}
