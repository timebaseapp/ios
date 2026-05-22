import SwiftUI

@main
struct TimebaseApp: App {
    @State private var store = TimebaseStore()
    @State private var motion = MotionStore()
    @Environment(\.scenePhase) private var scenePhaseEnvironment

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(motion)
                .preferredColorScheme(store.settings.appearance.preferred)
                .task {
                    #if DEBUG
                    if MarketingCapture.isActive {
                        await runMarketingCapture()
                        return
                    }
                    #endif
                    await store.bootstrap()
                    autoRotateIfNeeded()
                    Greeting.updateDynamicShortcut()
                    motion.start()
                    await SpotlightIndexer.reindex(cities: store.cities)
                }
                .onChange(of: scenePhaseEnvironment) { _, phase in
                    switch phase {
                    case .active:
                        autoRotateIfNeeded()
                        Greeting.updateDynamicShortcut()
                        motion.start()
                        consumePendingIntent()
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

    /// PlanMeetingIntent stashes flags in the App Group when run; pick them
    /// up here when the host app returns to the foreground.
    @MainActor
    private func consumePendingIntent() {
        let defaults = TimebaseStore.sharedDefaults
        if defaults.bool(forKey: "timebase.pendingShowScheduler") {
            defaults.removeObject(forKey: "timebase.pendingShowScheduler")
            store.goTo(tab: .upNextAbout)
            store.pendingShowScheduler = true
        }
    }

    #if DEBUG
    @MainActor
    private func runMarketingCapture() async {
        // Bypass the normal bootstrap — load DB then seed marketing state.
        store.cityDatabaseLoadIfNeeded()
        store.seedMarketingState()
        // Let SwiftUI lay out the seeded root view before we start snapping.
        try? await Task.sleep(for: .milliseconds(1200))
        let steps = TimebaseCaptureSteps.make(store: store)
        await MarketingCaptureCoordinator.shared.run(steps: steps) {
            MarketingElementHarness.renderAllWidgets()
        }
    }
    #endif

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
