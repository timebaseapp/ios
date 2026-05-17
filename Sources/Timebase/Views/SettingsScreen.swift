import SwiftUI

struct SettingsScreen: View {
    @Environment(TimebaseStore.self) private var store
    @State private var showAddSheet = false
    @State private var showResetConfirm = false

    var body: some View {
        @Bindable var bindable = store

        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                TrafficLightsBar()

                ScreenHeader(title: "Settings")
                    .padding(.top, 2)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 26) {
                        section(title: "CITIES") {
                            Button {
                                showAddSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Add city")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)

                            ForEach(store.orderedCities) { city in
                                cityRow(city)
                            }
                        }

                        section(title: "PREFERENCES") {
                            HStack {
                                Text("24-hour time")
                                    .font(.system(size: 16))
                                Spacer()
                                Picker("", selection: $bindable.settings.hourPreference) {
                                    Text("System").tag(HourPreference.system)
                                    Text("On").tag(HourPreference.on)
                                    Text("Off").tag(HourPreference.off)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)

                            HStack {
                                Text("Theme")
                                    .font(.system(size: 16))
                                Spacer()
                                Picker("", selection: $bindable.settings.appearance) {
                                    Text("System").tag(Appearance.system)
                                    Text("Light").tag(Appearance.light)
                                    Text("Dark").tag(Appearance.dark)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)

                            HStack {
                                Text("Calendar")
                                    .font(.system(size: 16))
                                Spacer()
                                if store.calendarAccessGranted {
                                    Text("Connected")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button("Connect") {
                                        Task { await store.requestCalendarAccess() }
                                    }
                                    .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                        }

                        section(title: "COMING SOON") {
                            comingSoonRow("Alternate app icons")
                            comingSoonRow("Pro")
                        }

                        section(title: "DANGER") {
                            Button(role: .destructive) {
                                showResetConfirm = true
                            } label: {
                                HStack {
                                    Text("Reset all data")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                            }
                            .foregroundStyle(.red)
                        }

                        AboutFooter()
                            .padding(.top, 30)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet()
        }
        .confirmationDialog(
            "Reset all data?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive) {
                store.resetAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clears your cities, settings, and onboarding state on this device and in iCloud. You'll see the onboarding again on next launch.")
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.custom("DepartureMono-Regular", size: 11))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    @ViewBuilder
    private func cityRow(_ city: City) -> some View {
        HStack(spacing: 8) {
            if city.id == store.homeCityId {
                Text("🏠")
                    .font(.system(size: 14))
            }
            Text(city.name)
                .font(.system(size: 16))
            Spacer()
            if city.id != store.homeCityId {
                Button {
                    store.makeHome(cityId: city.id)
                } label: {
                    Text("Set home")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    store.remove(cityId: city.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    @ViewBuilder
    private func comingSoonRow(_ label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Spacer()
            Text("—")
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
