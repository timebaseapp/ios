import SwiftUI

struct AboutSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindable = store

        ZStack {
            // Subtle background tint that picks up theme. Liquid Glass on iOS 26.
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 4) {
                    // Wordmark — system serif "New York" approximates the
                    // Crimson Text feel of the web version.
                    Text("Timebase")
                        .font(.custom("NewYork-Bold", size: 52, relativeTo: .largeTitle))
                        .kerning(-0.5)
                        .padding(.top, 14)

                    Text("v1.0 · 2026")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 22)

                    Text("A quieter way to think across timezones.")
                        .font(.system(size: 15, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    Text("A minimal world clock. Drag, scroll, or scrub to see what time it'll be anywhere.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 22)

                    // Settings card
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.primary.opacity(0.10), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)

                    Divider().padding(.horizontal, 28).padding(.bottom, 12)

                    HStack(spacing: 6) {
                        Text("Crafted by")
                            .foregroundStyle(.secondary)
                        Link("@amrith", destination: URL(string: "https://x.com/amrith")!)
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 12, design: .monospaced))

                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/timebaseapp")!) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.primary.opacity(0.05)))
                        }
                        Link(destination: URL(string: "https://x.com/amrith")!) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.primary.opacity(0.05)))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
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
                .font(.system(size: 11, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }
}
