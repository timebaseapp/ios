import SwiftUI

/// The main Timebase window. World clock (rows + timeline matrix toggle) is
/// the next surface to land — for now this is a calm placeholder so opening
/// Timebase from the menubar shows the brand and points at the menubar as
/// the live surface.
struct MainWindow: View {
    @Environment(TimebaseMacStore.self) private var store

    @State private var tick = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let hour = ClockMath.fractionalHour(in: store.homeTimeZone, date: tick)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)

        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Timebase")
                    .font(Brand.serif(52))
                Text("A quieter way to think across timezones.")
                    .font(Brand.mono(13))
                    .opacity(0.7)
                Text("World clock, scheduler, command palette — coming next. The menubar is live now.")
                    .font(Brand.mono(11))
                    .opacity(0.5)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .frame(maxWidth: 460)
            }
            .foregroundStyle(fg)
            .padding(40)
        }
        .onReceive(timer) { tick = $0 }
        .task { store.bootstrap() }
    }
}
