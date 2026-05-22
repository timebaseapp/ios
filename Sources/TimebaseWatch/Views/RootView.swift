import SwiftUI

/// The three top-level pages, swiped horizontally — mirroring the iOS tab
/// layout: countdowns on the left, the world clock in the middle, settings
/// on the right.
enum WatchPage: Hashable {
    case upNext, worldClock, settings
}

/// The app root — a horizontal page `TabView` with the page index hidden
/// (the layout is intuitive and matches iOS). The world clock is the centre
/// page and the default. Tapping a city band raises its detail as a
/// full-screen layer above the pages; tapping the detail dismisses it — no
/// back button. Complication deep links drive the same pages.
struct RootView: View {
    @Environment(TimebaseWatchStore.self) private var store
    @State private var page: WatchPage = .worldClock
    @State private var detailCity: City?
    @State private var detailEvent: UpcomingEvent?

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                UpNextScreen(onSelectEvent: { detailEvent = $0 })
                    .tag(WatchPage.upNext)

                WorldClockList(onSelectCity: { detailCity = $0 })
                    .tag(WatchPage.worldClock)

                SettingsPage()
                    .tag(WatchPage.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if let city = detailCity {
                CityDetailView(city: city) { detailCity = nil }
                    .transition(.opacity)
                    .zIndex(1)
            } else if let event = detailEvent {
                EventDetailView(event: event) { detailEvent = nil }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: detailCity)
        .animation(.easeInOut(duration: 0.22), value: detailEvent)
        .onChange(of: store.pendingRoute) { _, route in
            guard let route else { return }
            switch route {
            case .upNext:
                page = .upNext
            case .clock(let cityId):
                page = .worldClock
                if let cityId,
                   let city = store.cities.first(where: { $0.id == cityId }) {
                    detailCity = city
                }
            }
            store.pendingRoute = nil
        }
    }
}
