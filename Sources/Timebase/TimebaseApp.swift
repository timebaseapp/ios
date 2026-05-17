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
            MainPager()
        }
    }
}

struct MainPager: View {
    @Environment(TimebaseStore.self) private var store

    var body: some View {
        @Bindable var bindable = store
        TabView(selection: $bindable.currentTab) {
            UpNextAboutScreen().tag(ScreenTab.upNextAbout)
            ClockListView().tag(ScreenTab.clock)
            SettingsScreen().tag(ScreenTab.settings)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .top)
        .onAppear { Haptics.prepare() }
    }
}
