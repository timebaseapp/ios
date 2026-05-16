import SwiftUI

@main
struct TimebaseApp: App {
    @State private var store = TimebaseStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
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
            MainTabsView()
        }
    }
}

struct MainTabsView: View {
    @Environment(TimebaseStore.self) private var store
    @State private var selectedTab: Tab = .clock

    enum Tab { case clock, upNext }

    var body: some View {
        TabView(selection: $selectedTab) {
            ClockListView()
                .tabItem { Label("Clock", systemImage: "circle.lefthalf.filled") }
                .tag(Tab.clock)

            UpNextView()
                .tabItem { Label("Up Next", systemImage: "calendar") }
                .tag(Tab.upNext)
                .badge(store.upcomingEventsCount)
        }
        .tint(.primary)
    }
}
