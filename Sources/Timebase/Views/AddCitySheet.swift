import SwiftUI

struct AddCitySheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if filteredCities.isEmpty && !query.isEmpty {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        Section(query.isEmpty ? "Suggested" : "Results") {
                            ForEach(filteredCities) { city in
                                cityRow(city)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                       prompt: "Search 1,500+ cities")
            .navigationTitle("Add city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filteredCities: [City] {
        if query.isEmpty {
            return store.cityDatabase.filter { $0.popular }
        }
        let q = query.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        return store.cityDatabase.filter { city in
            let n = city.name.folding(options: .diacriticInsensitive, locale: nil).lowercased()
            let c = city.country.folding(options: .diacriticInsensitive, locale: nil).lowercased()
            return n.contains(q) || c.contains(q)
        }
    }

    private func cityRow(_ city: City) -> some View {
        let alreadyAdded = store.cities.contains(where: { $0.id == city.id })
        return HStack {
            Text(city.name)
            Spacer()
            Text(alreadyAdded ? "\(city.country) · added" : city.country)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .opacity(alreadyAdded ? 0.5 : 1)
        .onTapGesture {
            if !alreadyAdded {
                store.add(city: city)
                dismiss()
            }
        }
    }
}
