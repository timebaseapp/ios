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
                        section(title: "HOME") {
                            if let home = store.homeCity {
                                HStack {
                                    Text(home.name)
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text(home.country)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                            } else {
                                Text("Home will be set from your location")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                            }
                        }

                        section(title: "CITIES") {
                            Button {
                                showAddSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(store.isAtCityCap ? "Maximum reached (\(TimebaseStore.maxCities))" : "Add city")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isAtCityCap)
                            .opacity(store.isAtCityCap ? 0.45 : 1)

                            ForEach(nonHomeCities) { city in
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

                        section(title: "APP ICON") {
                            iconRow
                            autoRotateRow(bindable: $bindable)
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

    @State private var currentIcon = AppIconManager.currentName

    private var iconRow: some View {
        // 5 thumbnails — tighter spacing to fit on a 393pt-wide iPhone.
        HStack(spacing: 6) {
            ForEach(Array(zip(AppIconManager.names, AppIconManager.labels)), id: \.0) { (name, label) in
                Button {
                    AppIconManager.setIcon(name)
                    currentIcon = name
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            let previewName = name.replacingOccurrences(of: "AppIcon-", with: "IconPreview-")
                            if let img = UIImage(named: previewName) {
                                Image(uiImage: img)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 48, height: 48)
                            }
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(.black.opacity(0.10), lineWidth: 0.5)
                                .frame(width: 48, height: 48)
                            if currentIcon == name {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(.primary, lineWidth: 2)
                                    .frame(width: 54, height: 54)
                            }
                        }
                        .frame(width: 54, height: 54)

                        Text(label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
    }

    private func autoRotateRow(bindable: Bindable<TimebaseStore>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-rotate through the day")
                    .font(.system(size: 16))
                if bindable.wrappedValue.settings.autoRotateIcon {
                    Text("Shows an iOS alert on each switch")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: bindable.settings.autoRotateIcon)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }

    private var nonHomeCities: [City] {
        store.orderedCities.filter { $0.id != store.homeCityId }
    }

    @ViewBuilder
    private func cityRow(_ city: City) -> some View {
        HStack(spacing: 8) {
            Text(city.name)
                .font(.system(size: 16))
            Spacer()
            Button(role: .destructive) {
                store.remove(cityId: city.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

}
