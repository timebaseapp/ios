import SwiftUI

struct SettingsScreen: View {
    @Environment(TimebaseStore.self) private var store
    @State private var showAddSheet = false

    var body: some View {
        @Bindable var bindable = store

        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                TrafficLightsBar()

                ScrollView {
                    VStack(spacing: 26) {
                        // Wordmark header — quieter than About screen
                        Text("Settings")
                            .font(.custom("CrimsonText-SemiBold", size: 32))
                            .kerning(-0.2)
                            .padding(.top, 4)

                        section(title: "CITIES") {
                            Button {
                                showAddSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .heavy))
                                    Text("Add city")
                                        .font(.custom("DepartureMono-Regular", size: 13))
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
                                    .font(.custom("DepartureMono-Regular", size: 13))
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
                                    .font(.custom("DepartureMono-Regular", size: 13))
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
                                    .font(.custom("DepartureMono-Regular", size: 13))
                                Spacer()
                                if store.calendarAccessGranted {
                                    Text("Connected")
                                        .font(.custom("DepartureMono-Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button("Connect") {
                                        Task { await store.requestCalendarAccess() }
                                    }
                                    .font(.custom("DepartureMono-Regular", size: 11))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                        }

                        section(title: "COMING SOON") {
                            comingSoonRow("Alternate app icons")
                            comingSoonRow("Pro")
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet()
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
        HStack {
            if city.id == store.homeCityId {
                Text("🏠")
                    .font(.system(size: 14))
            }
            Text(city.name)
                .font(.custom("DepartureMono-Regular", size: 13))
            Spacer()
            if city.id != store.homeCityId {
                Button {
                    store.makeHome(cityId: city.id)
                } label: {
                    Text("Set home")
                        .font(.custom("DepartureMono-Regular", size: 10))
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    store.remove(cityId: city.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
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
                .font(.custom("DepartureMono-Regular", size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text("—")
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
