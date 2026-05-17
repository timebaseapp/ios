import SwiftUI

@main
struct TimebaseApp: App {
    @State private var store = TimebaseStore()
    @State private var motion = MotionStore()
    @StateObject private var weather = WeatherStore()
    @Environment(\.scenePhase) private var scenePhaseEnvironment

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(motion)
                .environmentObject(weather)
                .preferredColorScheme(store.settings.appearance.preferred)
                .task {
                    await store.bootstrap()
                    autoRotateIfNeeded()
                    Greeting.updateDynamicShortcut()
                    motion.start()
                    await SpotlightIndexer.reindex(cities: store.cities)
                    await weather.refreshAll(cities: store.cities)
                }
                .onChange(of: scenePhaseEnvironment) { _, phase in
                    switch phase {
                    case .active:
                        autoRotateIfNeeded()
                        Greeting.updateDynamicShortcut()
                        motion.start()
                    case .background:
                        motion.stop()
                    default:
                        break
                    }
                }
                .onOpenURL { url in
                    DeepLinkRouter.handle(url: url, store: store)
                }
        }
    }

    @MainActor
    private func autoRotateIfNeeded() {
        guard store.settings.autoRotateIcon else { return }
        let target = store.currentBucketIconName()
        AppIconManager.setIcon(target)
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
            UpNextScreen().tag(ScreenTab.upNextAbout)
            ClockListView().tag(ScreenTab.clock)
            SettingsScreen().tag(ScreenTab.settings)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onAppear { Haptics.prepare() }
    }
}
