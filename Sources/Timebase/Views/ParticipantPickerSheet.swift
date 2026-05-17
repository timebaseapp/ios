import SwiftUI

/// City picker for the Scheduler that returns a chosen City via callback
/// instead of mutating `store.cities` (which would change the world clock).
struct ParticipantPickerSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let excludedIds: Set<String>
    let onPick: (City) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section(query.isEmpty ? "Suggested" : "Results") {
                    ForEach(filtered) { city in
                        Button {
                            onPick(city)
                            dismiss()
                        } label: {
                            HStack {
                                Text(city.name).foregroundStyle(.primary)
                                Spacer()
                                Text(city.country)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(excludedIds.contains(city.id))
                        .opacity(excludedIds.contains(city.id) ? 0.4 : 1)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query,
                       placement: .navigationBarDrawer(displayMode: .always),
                       prompt: "Search cities")
            .navigationTitle("Add participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filtered: [City] {
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
}
