import SwiftUI

/// The world-clock page: every city as a full-bleed gradient band. The Watch
/// shows at most four cities, so the bands always divide the screen exactly
/// — no scrolling. The Digital Crown, and only the Crown, scrubs every band
/// together. Tapping a band opens its detail (or snaps to now when scrubbed).
struct WorldClockList: View {
    @Environment(TimebaseWatchStore.self) private var store
    let onSelectCity: (City) -> Void

    /// Crown-bound scrub value in minutes, mirrored into the shared store.
    @State private var crownMinutes: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let cities = store.orderedCities
            let count = max(cities.count, 1)
            // The system clock occupies the top ~36pt. Four perfectly equal
            // bands physically can't clear it — the row content is as tall
            // as the post-clock space. So the first band absorbs an extra
            // sliver of height; the remaining bands stay equal to each other,
            // and every band still bleeds edge to edge.
            let clockBand: CGFloat = 14
            let base = (proxy.size.height - clockBand) / CGFloat(count)
            let firstBand = base + clockBand

            VStack(spacing: 0) {
                if cities.isEmpty {
                    emptyHint.frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    ForEach(Array(cities.enumerated()), id: \.element.id) { idx, city in
                        CityRow(
                            city: city,
                            bandHeight: idx == 0 ? firstBand : base,
                            topInset: idx == 0 ? min(36, firstBand * 0.5) : 0,
                            bottomInset: idx == count - 1 ? 12 : 0
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if store.scrubOffsetMinutes != 0 {
                                store.snapToNow()
                                crownMinutes = 0
                            } else {
                                onSelectCity(city)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .focusable(true)
        .digitalCrownRotation(
            $crownMinutes,
            from: -TimebaseWatchStore.scrubBoundMinutes,
            through: TimebaseWatchStore.scrubBoundMinutes,
            by: 5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownMinutes) { _, new in
            store.scrubOffsetMinutes = new
        }
        .onChange(of: store.scrubOffsetMinutes) { _, new in
            if abs(crownMinutes - new) > 0.5 { crownMinutes = new }
        }
        .overlay(alignment: .bottom) {
            if store.scrubOffsetMinutes != 0 {
                Button {
                    store.snapToNow()
                    crownMinutes = 0
                } label: {
                    Text(store.scrubDeltaText())
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 11)
                        .padding(.vertical, 3.5)
                }
                .buttonStyle(SkeuomorphicScrubPill(scheme: .dark))
                .padding(.bottom, 8)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85),
                   value: store.scrubOffsetMinutes == 0)
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text("No cities yet")
                .font(.system(size: 16, weight: .regular))
            Text("Add cities in Settings.")
                .font(Brand.mono(9))
                .multilineTextAlignment(.center)
                .opacity(0.6)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: Palette.backgroundGradient(forHour: 2, scheme: .dark),
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

/// The scrub-offset pill — the Teenage-Engineering-style skeuomorphic pill
/// from iOS, ported to the wrist: a warm gradient capsule with paper grain,
/// an inset top highlight, an edge stroke, and a soft drop shadow.
struct SkeuomorphicScrubPill: ButtonStyle {
    let scheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        let dark = scheme != .light
        let topFill = dark ? Color(red: 0.18, green: 0.165, blue: 0.14)
                           : Color(red: 0.961, green: 0.949, blue: 0.925)
        let botFill = dark ? Color(red: 0.10, green: 0.090, blue: 0.078)
                           : Color(red: 0.878, green: 0.855, blue: 0.816)
        let edge = dark ? Color.black.opacity(0.55) : Color.black.opacity(0.18)
        let textColor = dark ? Color(red: 0.94, green: 0.92, blue: 0.886)
                             : Color(red: 0.11, green: 0.11, blue: 0.12)

        return configuration.label
            .foregroundStyle(textColor)
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [topFill, botFill],
                                             startPoint: .top, endPoint: .bottom))
                    Image("grain")
                        .resizable(resizingMode: .tile)
                        .blendMode(.overlay)
                        .opacity(0.55)
                        .clipShape(Capsule(style: .continuous))
                        .allowsHitTesting(false)
                    Capsule(style: .continuous)
                        .strokeBorder(edge, lineWidth: 0.5)
                    Capsule(style: .continuous)
                        .inset(by: 1)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(dark ? 0.10 : 0.55), .white.opacity(0)],
                                startPoint: .top, endPoint: .center),
                            lineWidth: 1)
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
