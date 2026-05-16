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
        .ignoresSafeArea(edges: .top)
        .universalScrub()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Dock(
                onAbout: { showAbout = true },
                onAdd:   { showAddSheet = true },
                onMiddleTap: { handleMiddleTap() }
            )
            .padding(.top, 10)
            .padding(.bottom, 10)
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

            if store.scrubOffsetMinutes != 0 {
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.scrubOffsetMinutes != 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: nextEvent?.id)
    }

    private var nextEvent: UpcomingEvent? {
        store.upcomingEvents.first(where: { $0.startDate > .now })
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

/// Liquid-Glass-style pill: ultraThinMaterial on iOS 26+ automatically renders
/// as Liquid Glass; on earlier iOS it's the familiar blurred translucency.
/// A thin highlight + outline keeps it tactile.
private struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
