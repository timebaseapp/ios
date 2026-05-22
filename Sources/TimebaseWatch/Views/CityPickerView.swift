import SwiftUI

/// The Add City screen — a searchable list over the bundled city database,
/// the watchOS counterpart of the iOS AddCitySheet. Tapping a city adds it
/// to the synced list, which writes back to iCloud and reaches every device.
struct CityPickerView: View {
    @Environment(TimebaseWatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var database: [City] = []

    var body: some View {
        List {
            if store.isAtCityCap {
                Text("You've reached the \(TimebaseWatchStore.maxCities)-city limit. Remove a city to add another.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if results.isEmpty {
                Text(query.isEmpty ? "Loading cities…" : "No cities match “\(query)”.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { city in
                    Button {
                        store.addCity(city)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(city.name)
                                .font(.system(size: 15))
                            Text(city.country)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search cities")
        .navigationTitle("Add City")
        .task {
            if database.isEmpty { database = City.loadBundled() }
        }
    }

    /// Every bundled city not already added, sorted by name, filtered by the
    /// search query — the full database, matching iOS.
    private var results: [City] {
        let added = Set(store.cities.map(\.id))
        let available = database.filter { !added.contains($0.id) }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matched = q.isEmpty
            ? available
            : available.filter { $0.name.lowercased().contains(q)
                              || $0.country.lowercased().contains(q) }
        return matched.sorted { $0.name < $1.name }
    }
}
