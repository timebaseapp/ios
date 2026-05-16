import SwiftUI

struct AboutSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private var sheetBg: Color {
        scheme == .dark ? Color(red: 0.102, green: 0.102, blue: 0.110)
                        : Color(red: 1, green: 1, blue: 1)
    }

    var body: some View {
        @Bindable var bindable = store

        ZStack {
            sheetBg.ignoresSafeArea()

            // Paper-grain overlay (matches web .about-card::before)
            Image("grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.45)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Traffic lights — top-left
                HStack(spacing: 8) {
                    TrafficLight(color: Color(red: 1.0, green: 0.373, blue: 0.341),
                                 symbol: "xmark", showSymbol: true) { dismiss() }
                    TrafficLight(color: Color(red: 1.0, green: 0.741, blue: 0.180),
                                 symbol: "minus", showSymbol: false) { }
                    TrafficLight(color: Color(red: 0.157, green: 0.788, blue: 0.251),
                                 symbol: "square", showSymbol: false) { }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Spacer(minLength: 0)

                Text("Timebase")
                    .font(.custom("CrimsonText-SemiBold", size: 52))
                    .kerning(-0.4)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 6)

                Text("v1.0 · 2026")
                    .font(.custom("DepartureMono-Regular", size: 11))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)

                Text("A quieter way to think across timezones.")
                    .font(.custom("DepartureMono-Regular", size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                Text("A minimal world clock. Drag, scroll, or scrub to see what time it'll be anywhere.")
                    .font(.custom("DepartureMono-Regular", size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)

                // Inline settings card
                VStack(spacing: 10) {
                    SettingRow(label: "24-HOUR TIME") {
                        Picker("", selection: $bindable.settings.hourPreference) {
                            Text("System").tag(HourPreference.system)
                            Text("On").tag(HourPreference.on)
                            Text("Off").tag(HourPreference.off)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    SettingRow(label: "THEME") {
                        Picker("", selection: $bindable.settings.appearance) {
                            Text("System").tag(Appearance.system)
                            Text("Light").tag(Appearance.light)
                            Text("Dark").tag(Appearance.dark)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.primary.opacity(0.10), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                Divider().padding(.horizontal, 28).padding(.bottom, 14)

                HStack(spacing: 6) {
                    Text("Crafted by")
                        .foregroundStyle(.secondary)
                    Link("@amrith", destination: URL(string: "https://x.com/amrith")!)
                        .foregroundStyle(.primary)
                        .underline()
                }
                .font(.custom("DepartureMono-Regular", size: 11))

                HStack(spacing: 14) {
                    Link(destination: URL(string: "https://github.com/timebaseapp")!) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    Link(destination: URL(string: "https://x.com/amrith")!) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("DepartureMono-Regular", size: 11))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }
}

/// macOS-style traffic-light button.
private struct TrafficLight: View {
    let color: Color
    let symbol: String
    let showSymbol: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                Circle().stroke(.black.opacity(0.18), lineWidth: 0.5)
                if showSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 6, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
    }
}
