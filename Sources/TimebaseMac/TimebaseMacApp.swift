import SwiftUI

/// The Timebase macOS app. The menubar is the priority surface — always
/// present, calm — and the main window opens behind it when the wearer
/// wants the full world clock. Both share one `TimebaseMacStore`.
@main
struct TimebaseMacApp: App {
    @State private var store = TimebaseMacStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontRegistration.registerBrandFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            MenubarView()
                .environment(store)
        } label: {
            MenubarStatusLabel()
                .environment(store)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Timebase", id: "main") {
            MainWindow()
                .environment(store)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 960, height: 640)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.bootstrap() }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
