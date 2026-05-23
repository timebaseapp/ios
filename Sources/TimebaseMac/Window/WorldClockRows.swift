import SwiftUI

/// The world clock as full-window-width gradient rows. ⌘1 view of the main
/// window. Equal-height bands divide the window; tapping a row reveals its
/// detail. The scrub pill at the bottom shows the scrubbed offset and snaps
/// to now on click.
struct WorldClockRows: View {
    @Environment(TimebaseMacStore.self) private var store
    @State private var detailCity: City?

    var body: some View {
        GeometryReader { proxy in
            let cities = store.orderedCities
            ZStack(alignment: .bottom) {
                if cities.isEmpty {
                    emptyHint.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(cities) { city in
                            MacCityRow(city: city)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if store.scrubOffsetMinutes != 0 {
                                        store.snapToNow()
                                    } else {
                                        detailCity = city
                                    }
                                }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }

                if store.scrubOffsetMinutes != 0 {
                    Button {
                        store.snapToNow()
                    } label: {
                        Text(scrubDeltaText)
                            .font(.system(size: 14, weight: .heavy))
                            .monospacedDigit()
                            .padding(.horizontal, 20)
                            .frame(height: 38)
                    }
                    .buttonStyle(SkeuomorphicPillButtonStyle())
                    .padding(.bottom, 22)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: store.scrubOffsetMinutes == 0)
        }
        .ignoresSafeArea()
        .sheet(item: $detailCity) { city in
            CityDetailPopover(city: city)
                .environment(store)
                .frame(width: 380, height: 380)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("No cities yet")
                .font(Brand.serif(22))
            Text("Add cities from the menubar's Customize sheet.")
                .font(Brand.mono(11))
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    /// `+3h`, `−1d 4h` — same format as iOS `ClockListView.scrubDeltaText`.
    private var scrubDeltaText: String {
        let minutes = Int(store.scrubOffsetMinutes.rounded())
        let sign = minutes >= 0 ? "+" : "−"
        let abs = Swift.abs(minutes)
        let days = abs / 1440
        let hours = (abs % 1440) / 60
        let mins = abs % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if mins > 0 && days == 0 { parts.append("\(mins)m") }
        if parts.isEmpty { parts.append("0m") }
        return "\(sign)\(parts.joined(separator: " "))"
    }
}
