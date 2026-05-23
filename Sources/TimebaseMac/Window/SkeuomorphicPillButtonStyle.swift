import SwiftUI

/// The Teenage-Engineering / Braun pill button, ported from the iOS
/// `SharedScreenChrome.swift`. Warm gradient capsule, paper grain overlay,
/// inset top highlight, edge stroke, soft drop shadow. Used by the scrub
/// pill and other tactile call-to-action buttons.
struct SkeuomorphicPillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

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
