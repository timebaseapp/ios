import SwiftUI

/// The settings page — the right-hand screen, kept in close parity with the
/// iOS Settings tab for everything that applies to the wrist: the home city,
/// a full add/remove city picker, the clock and theme preferences, the
/// calendar control, and an about footer.
struct SettingsPage: View {
    @Environment(TimebaseWatchStore.self) private var store
    @State private var requestingCalendar = false

    var body: some View {
        NavigationStack {
            List {
                Section("Home") {
                    Text(store.homeCity?.name ?? "Not set")
                        .foregroundStyle(.secondary)
                }

                Section("Cities") {
                    NavigationLink {
                        CityPickerView()
                    } label: {
                        Label(store.isAtCityCap ? "City limit reached" : "Add city",
                              systemImage: "plus")
                    }
                    .disabled(store.isAtCityCap)

                    ForEach(store.orderedCities) { city in
                        HStack {
                            Text(city.name)
                            Spacer()
                            if city.id == store.homeCityId {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(role: .destructive) {
                                    store.removeCity(city.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Preferences") {
                    Picker("24-hour time", selection: hourBinding) {
                        Text("System").tag(HourPreference.system)
                        Text("On").tag(HourPreference.on)
                        Text("Off").tag(HourPreference.off)
                    }
                    .pickerStyle(.navigationLink)

                    calendarRow
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timebase")
                            .font(Brand.serif(20))
                        Text("A quieter way to think across timezones.")
                            .font(Brand.mono(9))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Version \(appVersion)")
                            .font(Brand.mono(9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var calendarRow: some View {
        if store.calendarAccessGranted {
            HStack {
                Text("Calendar")
                Spacer()
                Text("Connected").foregroundStyle(.secondary)
            }
        } else {
            Button {
                requestingCalendar = true
                Task {
                    await store.requestCalendarAccess()
                    requestingCalendar = false
                }
            } label: {
                HStack {
                    Text("Calendar")
                    Spacer()
                    Text(requestingCalendar ? "Requesting…" : "Connect")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(requestingCalendar)
        }
    }

    /// Reads the effective 24-hour value, writes the watch-local override.
    private var hourBinding: Binding<HourPreference> {
        Binding(
            get: { store.effectiveHourPreference },
            set: { store.hourPreferenceOverride = $0 }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
