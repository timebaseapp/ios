import SwiftUI

struct SettingsSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindable = store
        NavigationStack {
            Form {
                Section("Time") {
                    Picker("24-hour time", selection: $bindable.settings.hourPreference) {
                        Text("System").tag(HourPreference.system)
                        Text("On").tag(HourPreference.on)
                        Text("Off").tag(HourPreference.off)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $bindable.settings.appearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                }

                Section("Calendar") {
                    if store.calendarAccessGranted {
                        Text("Connected").foregroundStyle(.secondary)
                    } else {
                        Button("Connect Calendar") {
                            Task { await store.requestCalendarAccess() }
                        }
                    }
                    Text("Managed in iOS Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                    Link("Open source licenses", destination: URL(string: "https://github.com/timebaseapp")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
