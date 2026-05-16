import SwiftUI

struct ClockListView: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    @State private var detailCity: City?
    @State private var showAddSheet = false
    @State private var showSettings = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(store.cities) { city in
                    CityRow(city: city, isHome: city.id == store.homeCityId)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { detailCity = city }
                        .contextMenu {
                            if city.id != store.homeCityId {
                                Button("Make home") { store.makeHome(cityId: city.id) }
                                Button("Remove", role: .destructive) { store.remove(cityId: city.id) }
                            } else {
                                Button("Add city") { showAddSheet = true }
                                Button("Settings") { showSettings = true }
                            }
                            Button("Details") { detailCity = city }
                        }
                }
            }
            .ignoresSafeArea()
            .universalScrub()

            // Floating pill: scrub or next event.
            VStack {
                Spacer()
                pillContent
                    .padding(.bottom, 24)
            }
            .allowsHitTesting(true)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in tick = Date() }
        .sheet(item: $detailCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        if store.scrubOffsetMinutes != 0 {
            Button(action: { store.snapToNow() }) {
                Text(scrubDeltaText)
                    .font(.system(size: 13, weight: .heavy))
                    .monospacedDigit()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.primary.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if let event = store.upcomingEvents.first, event.startDate > .now {
            Button(action: { /* tab switch handled by parent */ }) {
                Text("Next · \(nextEventDelta(event))")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.primary.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
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

    private func nextEventDelta(_ event: UpcomingEvent) -> String {
        let seconds = event.startDate.timeIntervalSince(.now)
        return TimebaseFormatters.relative(seconds: seconds)
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
