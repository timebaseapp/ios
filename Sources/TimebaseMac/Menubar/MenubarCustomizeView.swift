import SwiftUI

/// The customize editor — pick which up-to-4 cities appear in the menubar
/// popover. Home is always pinned (top, locked); the wearer toggles up to
/// three additional cities. Stored in Mac-local `UserDefaults` under
/// `macos.menubarCityIds` — never written to the shared `timebase.v1` blob.
struct MenubarCustomizeView: View {
    @Environment(TimebaseMacStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menubar cities")
                        .font(Brand.serif(20))
                    Text("Pick up to \(TimebaseMacStore.menubarCityCap) cities. Home is always shown.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
            }

            List {
                ForEach(store.orderedCities) { city in
                    cityRow(city)
                }
            }
            .listStyle(.plain)
        }
        .padding(20)
        .frame(width: 380, height: 460)
    }

    private func cityRow(_ city: City) -> some View {
        let isHome = city.id == store.homeCityId
        let pinned = isHome || store.isMenubarCityPinned(city.id)
        let nonHomePinnedCount = store.menubarCityIds.filter { $0 != store.homeCityId }.count
        let canPinMore = nonHomePinnedCount < (TimebaseMacStore.menubarCityCap - 1)
        let disabled = isHome || (!pinned && !canPinMore)

        return Button {
            if !isHome { store.toggleMenubarCity(city.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pinned ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(pinned ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(city.name).font(.system(size: 13))
                        if isHome {
                            Text("Home")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(city.country)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !pinned ? 0.5 : 1)
    }
}
