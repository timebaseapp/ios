import SwiftUI

struct ClockListView: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    @State private var detailCity: City?
    @State private var showAddSheet = false
    @State private var showAbout = false
    @State private var showUpNext = false

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

            Dock(
                onAbout: { showAbout = true },
                onAdd:   { showAddSheet = true },
                onMiddleTap: { handleMiddleTap() }
            )
            .padding(.bottom, 18)
        }
        .onReceive(timer) { _ in tick = Date() }
        .sheet(item: $detailCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet()
        }
        .sheet(isPresented: $showAbout) {
            AboutSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showUpNext) {
            UpNextView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func handleMiddleTap() {
        if store.scrubOffsetMinutes != 0 { store.snapToNow() }
        else if !store.upcomingEvents.isEmpty { showUpNext = true }
    }
}

// MARK: - Dock

private struct Dock: View {
    @Environment(TimebaseStore.self) private var store
    let onAbout: () -> Void
    let onAdd: () -> Void
    let onMiddleTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IconPill(action: onAbout) {
                Text("i")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .italic()
            }

            if scrubMinutes != 0 {
                TextPill(action: onMiddleTap, weight: .heavy) {
                    Text(scrubDeltaText)
                        .monospacedDigit()
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if let event = nextEvent {
                TextPill(action: onMiddleTap, weight: .medium) {
                    Text("Next · \(nextEventDelta(event))")
                        .monospacedDigit()
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            IconPill(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .heavy))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scrubMinutes != 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: nextEvent?.id)
    }

    /// Sub-minute drag jitter that rounds to 0 shouldn't trip the pill.
    private var scrubMinutes: Int {
        let rounded = Int(store.scrubOffsetMinutes.rounded())
        return Swift.abs(rounded) >= 1 ? rounded : 0
    }

    private var nextEvent: UpcomingEvent? {
        store.upcomingEvents.first(where: { $0.startDate > .now })
    }

    private var scrubDeltaText: String {
        let minutes = scrubMinutes
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
        TimebaseFormatters.relative(seconds: event.startDate.timeIntervalSince(.now))
    }
}

// MARK: - Pill primitives

private struct IconPill<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: 38, height: 38)
        }
        .buttonStyle(GlassPillButtonStyle())
    }
}

private struct TextPill<Content: View>: View {
    let action: () -> Void
    let weight: Font.Weight
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .font(.system(size: 13, weight: weight))
                .padding(.horizontal, 16)
                .frame(height: 38)
        }
        .buttonStyle(GlassPillButtonStyle())
    }
}

/// Skeuomorphic pill — matches web: warm cream gradient (Braun/TE feel),
/// inset highlight at top edge, outer cast shadow, paper-grain overlay.
/// Dark mode uses a warm walnut variant.
private struct GlassPillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let dark = scheme == .dark
        let topFill = dark ? Color(red: 0.18, green: 0.165, blue: 0.14)
                           : Color(red: 0.961, green: 0.949, blue: 0.925)
        let botFill = dark ? Color(red: 0.10, green: 0.090, blue: 0.078)
                           : Color(red: 0.878, green: 0.855, blue: 0.816)
        let edge   = dark ? Color.black.opacity(0.55) : Color.black.opacity(0.18)
        let textColor = dark ? Color(red: 0.94, green: 0.92, blue: 0.886)
                             : Color(red: 0.11, green: 0.11, blue: 0.12)

        return configuration.label
            .foregroundStyle(textColor)
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [topFill, botFill],
                                             startPoint: .top, endPoint: .bottom))

                    // Paper grain
                    Image("grain")
                        .resizable(resizingMode: .tile)
                        .blendMode(.overlay)
                        .opacity(0.55)
                        .clipShape(Capsule(style: .continuous))
                        .allowsHitTesting(false)

                    // Outer edge + inner highlight
                    Capsule(style: .continuous)
                        .strokeBorder(edge, lineWidth: 0.5)
                    Capsule(style: .continuous)
                        .inset(by: 1)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(dark ? 0.10 : 0.55),
                                    .white.opacity(0)
                                ],
                                startPoint: .top, endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(dark ? 0.35 : 0.10), radius: 4, y: 2)
                .shadow(color: .black.opacity(dark ? 0.20 : 0.06), radius: 1, y: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 0.5 : 0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

// MARK: - Shared formatter (kept here for reuse from previous version)

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
