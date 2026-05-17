import SwiftUI

/// The About content — extracted from the old AboutSheet so it can be
/// embedded inside the UpNext+About page rather than presented as a modal.
struct AboutCard: View {
    @Environment(TimebaseStore.self) private var store

    var body: some View {
        @Bindable var bindable = store

        VStack(spacing: 0) {
            Text("Timebase")
                .font(.custom("CrimsonText-SemiBold", size: 48))
                .kerning(-0.4)
                .foregroundStyle(.primary)
                .padding(.bottom, 6)

            Text("v1.0 · 2026")
                .font(.custom("DepartureMono-Regular", size: 11))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)

            Text("A quieter way to think across timezones.")
                .font(.custom("DepartureMono-Regular", size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

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

            Divider().padding(.horizontal, 28).padding(.bottom, 12)

            HStack(spacing: 6) {
                Text("Crafted by").foregroundStyle(.secondary)
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
                    Text("𝕏")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
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
