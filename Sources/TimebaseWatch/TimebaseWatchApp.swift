import SwiftUI

/// The standalone Timebase watchOS app. Runs with no iPhone present —
/// watchOS 10 makes standalone the default architecture. The paired iPhone
/// is an enhancement (events, Live Activities), never a requirement.
@main
struct TimebaseWatchApp: App {
    @State private var store = TimebaseWatchStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { store.bootstrap() }
                .onOpenURL { handleDeepLink($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.bootstrap() }
        }
    }

    /// Routes `timebase://` deep links from complication taps. The scheme is
    /// aligned with the iOS `DeepLinkRouter` hosts (`upnext`, `city`).
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "timebase" else { return }
        switch url.host {
        case "upnext":
            store.pendingRoute = .upNext
        case "city":
            let id = url.pathComponents.dropFirst().first
            store.pendingRoute = .clock(cityId: id)
        default:
            store.pendingRoute = .clock(cityId: nil)
        }
    }
}
