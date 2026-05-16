import SwiftUI

@main
struct TimebaseApp: App {
    @State private var store = TimebaseStore()
    @StateObject private var weather = WeatherStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environmentObject(weather)
                .preferredColorScheme(store.settings.appearance.preferred)
                .task {
                    await store.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @Environment(TimebaseStore.self) private var store

    var body: some View {
        if !store.hasCompletedOnboarding {
            OnboardingView()
        } else {
            ClockListView()
        }
    }
}
