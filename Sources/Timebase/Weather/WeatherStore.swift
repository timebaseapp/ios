import Foundation
import WeatherKit
import CoreLocation

/// Thin async wrapper around WeatherKit with a per-city TTL cache.
/// Fails gracefully (returns nil) if the entitlement isn't enabled — the UI
/// just hides the weather row.
@MainActor
final class WeatherStore: Observable {
    private let service = WeatherService.shared
    private var cache: [String: (current: CurrentWeather, time: Date)] = [:]
    private let ttl: TimeInterval = 15 * 60
    private var inFlight: Set<String> = []

    /// Last-fetched weather per city, keyed by `city.id`. SwiftUI observes this.
    @Published var snapshots: [String: CurrentWeather] = [:]

    func snapshot(for city: City) -> CurrentWeather? {
        if let entry = cache[city.id], Date.now.timeIntervalSince(entry.time) < ttl {
            return entry.current
        }
        return snapshots[city.id]
    }

    func refresh(for city: City) async {
        if let entry = cache[city.id], Date.now.timeIntervalSince(entry.time) < ttl {
            return
        }
        if inFlight.contains(city.id) { return }
        inFlight.insert(city.id)
        defer { inFlight.remove(city.id) }
        do {
            let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
            let weather = try await service.weather(for: location)
            let current = weather.currentWeather
            cache[city.id] = (current, Date.now)
            snapshots[city.id] = current
        } catch {
            // Most common cause: WeatherKit capability not enabled for the
            // bundle ID in Apple Developer portal. Fail silently.
            #if DEBUG
            print("WeatherKit error for \(city.name): \(error.localizedDescription)")
            #endif
        }
    }
}

/// `Observable` shim so we can `@Published` properties from a class that
/// declares plain `@MainActor final class`. Inherit from `ObservableObject`.
typealias Observable = ObservableObject
