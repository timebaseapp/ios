import SwiftUI

struct ClockListView: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    @State private var detailCity: City?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ForEach(store.orderedCities) { city in
                    CityRow(city: city)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { detailCity = city }
                        .contextMenu {
                            if city.id != store.homeCityId {
                                Button("Make home") { store.makeHome(cityId: city.id) }
                                Button("Remove", role: .destructive) { store.remove(cityId: city.id) }
                            }
                            Button("Details") { detailCity = city }
                        }
                }
            }
            .ignoresSafeArea()
            .universalScrub()

            // Scrub-delta pill — only floating element, only when offset != 0.
            if Swift.abs(Int(store.scrubOffsetMinutes.rounded())) >= 1 {
                Button {
                    Haptics.buttonPressed()
                    store.snapToNow()
                } label: {
                    Text(scrubDeltaText)
                        .font(.system(size: 13, weight: .heavy))
                        .monospacedDigit()
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                }
                .buttonStyle(SkeuomorphicPillButtonStyle())
                .padding(.bottom, 18)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: Swift.abs(Int(store.scrubOffsetMinutes.rounded())) >= 1)
        .onReceive(timer) { _ in tick = Date() }
        .sheet(item: $detailCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

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

enum TimebaseFormatters {
    static func relative(seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "now" }
        let m = s / 60
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let mm = m % 60
        if h < 24 { return mm > 0 ? "\(h)h \(mm)m" : "\(h)h" }
        let d = h / 24
        let hh = h % 24
        return hh > 0 ? "\(d)d \(hh)h" : "\(d)d"
    }
}
