import SwiftUI

struct ClockListView: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    @State private var detailCity: City?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Total vertical space the pill needs (height + bottom padding).
    /// Reserved at the bottom of the last city when scrubbed so the pill
    /// never obstructs row content.
    private let pillReservedSpace: CGFloat = 38 + 18 + 4

    private var pillVisible: Bool { store.scrubOffsetMinutes != 0 }

    var body: some View {
        // Outer GeometryReader reads the REAL safe area (the hosting
        // controller inside UniversalScrubContainer zeroes its own safe area
        // for full-bleed, so we capture insets here and pass them down).
        GeometryReader { proxy in
            let topSafe = proxy.safeAreaInsets.top
            let botSafe = proxy.safeAreaInsets.bottom
            let cities = store.orderedCities
            // Each row's natural breathing room above/below its content when
            // perfectly centered. We only inset content beyond that — pushing
            // it by the FULL safe area shoves it into the opposite border on
            // short rows (e.g., 8 cities).
            let rowHeight = proxy.size.height / max(CGFloat(cities.count), 1)
            let estimatedContentHeight: CGFloat = 50
            let naturalGap = max(0, (rowHeight - estimatedContentHeight) / 2)
            let topInset = max(0, topSafe - naturalGap)
            let botInset = max(0, botSafe - naturalGap)
            let lastBotInset = botInset + (pillVisible ? pillReservedSpace : 0)

            ZStack(alignment: .bottom) {
                UniversalScrubContainer(
                    content: VStack(spacing: 0) {
                        ForEach(Array(cities.enumerated()), id: \.element.id) { idx, city in
                            let isFirst = idx == 0
                            let isLast = idx == cities.count - 1
                            CityRow(
                                city: city,
                                rowCount: cities.count,
                                topContentInset: isFirst ? topInset : 0,
                                bottomContentInset: isLast ? lastBotInset : 0
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture {
                                // When scrubbed, the priority is getting
                                // back to "now" — tap anywhere returns to
                                // the present. Detail sheet only opens when
                                // we're already at present time.
                                if store.scrubOffsetMinutes != 0 {
                                    store.snapToNow()
                                } else {
                                    detailCity = city
                                }
                            }
                            .contextMenu {
                                if city.id != store.homeCityId {
                                    Button("Make home") { store.makeHome(cityId: city.id) }
                                    Button("Remove", role: .destructive) { store.remove(cityId: city.id) }
                                }
                                Button("Details") { detailCity = city }
                            }
                        }
                    }
                    .ignoresSafeArea(),
                    onVerticalPan: { dy in
                        store.scrubOffsetMinutes += Double(-dy) / scrubPixelsPerMinute
                        ScrubHaptics.update(store: store)
                    },
                    onDoubleTap: { store.snapToNow() },
                    onPinchStep: { direction in
                        store.pinchStep(direction: direction)
                    }
                )
                .ignoresSafeArea()

            // Scrub-delta pill — appears while scrubbed, auto-fades ~2s after
            // user stops scrubbing so it stops overlapping row content.
            if pillVisible {
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
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85)),
                    removal: .opacity.animation(.easeOut(duration: 0.6))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: pillVisible)
        .onReceive(timer) { _ in tick = Date() }
        .sheet(item: $detailCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        }   // end GeometryReader
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
