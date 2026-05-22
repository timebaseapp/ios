import SwiftUI

/// Settings — placeholder for v1; real Mac Settings scene (general,
/// menubar, calendar, about) lands alongside the main window work.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(Brand.serif(22))
            Text("Settings are coming. For now, customize menubar cities from the menubar popover.")
                .font(Brand.mono(11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(40)
        .frame(width: 480, height: 320)
    }
}
