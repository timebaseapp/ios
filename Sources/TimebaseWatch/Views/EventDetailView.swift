import SwiftUI

/// The event detail — a calm full screen tinted by the home time-of-day
/// color at the event's start. Title, a live ticking countdown, and when it
/// falls (home time, and the event's own zone when different). A tap
/// anywhere returns to Up Next — no back button.
struct EventDetailView: View {
    let event: UpcomingEvent
    let onDismiss: () -> Void

    @Environment(TimebaseWatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var aod

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let homeTZ = store.homeTimeZone
        let hour = ClockMath.fractionalHour(in: homeTZ, date: event.startDate)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark, aod: aod)
        let fg = Palette.foreground(forHour: hour, scheme: .dark, aod: aod)

        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 2)

                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                countdown
                    .padding(.top, 4)

                Spacer(minLength: 8)

                Text(homeWhenLine(homeTZ: homeTZ))
                    .font(Brand.mono(10))
                if event.timezone.identifier != homeTZ.identifier {
                    Text(eventWhenLine)
                        .font(Brand.mono(9))
                        .opacity(0.7)
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .gesture(DragGesture())
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var countdown: some View {
        if event.startDate > now {
            Text(timerInterval: now ... event.startDate, countsDown: true)
                .font(.system(size: 32, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        } else if event.endDate > now {
            Text("Happening now")
                .font(.system(size: 19, weight: .heavy))
        } else {
            Text("Ended")
                .font(.system(size: 19, weight: .heavy))
        }
    }

    private func homeWhenLine(homeTZ: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        fmt.timeZone = homeTZ
        let date = fmt.format(event.startDate)
        let time = ClockMath.timeString(date: event.startDate, tz: homeTZ,
                                        pref: store.effectiveHourPreference)
        return "\(date) · \(time)"
    }

    private var eventWhenLine: String {
        let time = ClockMath.timeString(date: event.startDate, tz: event.timezone,
                                        pref: store.effectiveHourPreference)
        let abbr = event.timezone.abbreviation(for: event.startDate) ?? ""
        return abbr.isEmpty ? time : "\(time) \(abbr)"
    }
}
