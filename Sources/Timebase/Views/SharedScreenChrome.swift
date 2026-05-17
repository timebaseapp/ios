import SwiftUI

/// Shared traffic-light bar used at the top of side screens (Up Next/About,
/// Settings). Red dismisses back to Clock; yellow + green are decorative
/// homage to macOS.
struct TrafficLightsBar: View {
    @Environment(TimebaseStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            TrafficLight(color: Color(red: 1.0, green: 0.373, blue: 0.341),
                         symbol: "xmark", showSymbol: true) {
                Haptics.buttonPressed()
                store.goTo(tab: .clock)
            }
            TrafficLight(color: Color(red: 1.0, green: 0.741, blue: 0.180),
                         symbol: "minus", showSymbol: false) { }
            TrafficLight(color: Color(red: 0.157, green: 0.788, blue: 0.251),
                         symbol: "square", showSymbol: false) { }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

private struct TrafficLight: View {
    let color: Color
    let symbol: String
    let showSymbol: Bool
    let action: () -> Void
    @State private var groupHover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                Circle().stroke(.black.opacity(0.18), lineWidth: 0.5)
                if showSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .frame(width: 13, height: 13)
        }
        .buttonStyle(.plain)
    }
}

/// Shared backdrop: app's near-neutral surface + paper grain + fluted glass
/// (subtle), matching the rest of the visual system.
struct BackgroundLayer: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
                ? Color(red: 0.094, green: 0.094, blue: 0.110)
                : Color(red: 0.973, green: 0.965, blue: 0.949))
                .ignoresSafeArea()

            // Flutes — vertical glass ribs
            Image("flutes")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Paper grain
            Image("grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.42)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// Re-exposed skeuomorphic pill style (matches the in-app pill aesthetic).
/// Identical visuals to the previous `GlassPillButtonStyle` in ClockListView,
/// hoisted here for reuse on screens beyond Clock.
struct SkeuomorphicPillButtonStyle: ButtonStyle {
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
