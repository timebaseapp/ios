import SwiftUI

/// The menubar popover — the daily-driver surface. A calm header, up to four
/// chosen cities as gradient strips, the next event with a Timebase-y
/// countdown (`5d 10h 22m 35s`), and a footer with quick actions.
struct MenubarView: View {
    @Environment(TimebaseMacStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var tick = Date()
    @State private var showCustomize = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            cities
                .padding(.horizontal, 8)

            Divider().padding(.vertical, 8)

            upNext
                .padding(.horizontal, 8)

            Divider().padding(.top, 8)

            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(width: 360)
        .task { store.bootstrap() }
        .onReceive(timer) { tick = $0 }
        .sheet(isPresented: $showCustomize) {
            MenubarCustomizeView()
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Timebase")
                .font(Brand.serif(17))
            Spacer()
            if let home = store.homeCity {
                Text("\(home.name) · \(ClockMath.timeString(date: tick, tz: home.timeZoneObject, pref: store.settings.hourPreference, showMeridiem: false))")
                    .font(Brand.mono(10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Cities

    private var cities: some View {
        VStack(spacing: 4) {
            if store.menubarCities.isEmpty {
                Text("No cities yet — open Timebase to add some.")
                    .font(Brand.mono(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(store.menubarCities) { city in
                    MenubarCityRow(city: city, now: tick)
                }
            }
        }
    }

    // MARK: - Up Next

    @ViewBuilder
    private var upNext: some View {
        if let event = store.nextEvent {
            eventCard(event)
        } else {
            HStack(spacing: 6) {
                Text(Brand.night).font(.system(size: 14))
                Text("Nothing on the calendar.")
                    .font(Brand.mono(11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }

    private func eventCard(_ event: UpcomingEvent) -> some View {
        let hour = ClockMath.fractionalHour(in: store.homeTimeZone, date: event.startDate)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("UP NEXT")
                    .font(Brand.mono(8))
                    .tracking(1.5)
                    .opacity(0.6)
                Spacer()
                Text(eventTimeLabel(event))
                    .font(Brand.mono(9))
                    .opacity(0.75)
            }
            Text(event.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            countdown(event)
        }
        .foregroundStyle(fg)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func countdown(_ event: UpcomingEvent) -> some View {
        if event.startDate > tick {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                Text(Countdown.format(to: event.startDate, from: context.date))
                    .font(.system(size: 20, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } else if event.endDate > tick {
            Text("Happening now")
                .font(.system(size: 18, weight: .heavy))
        } else {
            Text("Ended")
                .font(.system(size: 18, weight: .heavy))
        }
    }

    private func eventTimeLabel(_ event: UpcomingEvent) -> String {
        ClockMath.timeString(date: event.startDate, tz: store.homeTimeZone,
                             pref: store.settings.hourPreference)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Text("Open Timebase")
            }
            .keyboardShortcut("o", modifiers: .command)

            Spacer()

            Button {
                showCustomize = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Customize menubar cities")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Timebase")
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
    }
}
