import SwiftUI

/// The Up Next page — top 3 upcoming events with live countdowns. Each card
/// is tinted by the time-of-day color at the *home* timezone when the event
/// starts, so the cards feel like part of *your* day.
///
/// Scrolls only when there are events to scroll; an empty calendar is a
/// tight, centered page with no idle bounce.
struct UpNextScreen: View {
    /// Raises the event detail when a card is tapped.
    let onSelectEvent: (UpcomingEvent) -> Void

    @Environment(TimebaseWatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var tick = Date()
    @State private var requesting = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let events = store.nextThreeEvents
        Group {
            if events.isEmpty {
                emptyLayout
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        header
                        ForEach(events) { event in
                            EventCard(event: event, now: tick,
                                      homeTimeZone: store.homeTimeZone,
                                      aod: isLuminanceReduced, scheme: .dark)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelectEvent(event) }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .onReceive(timer) { _ in tick = Date() }
    }

    private var header: some View {
        Text("Up Next")
            .font(Brand.serif(20))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// No ScrollView when there is nothing to scroll — a tight, centered page.
    private var emptyLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 8)
                .padding(.top, 4)
            Spacer()
            if store.shouldOfferStandaloneCalendar {
                standaloneFallback
            } else {
                noEventsState
            }
            Spacer()
        }
    }

    /// The opt-in "Show my events" affordance — shown only when the Watch is
    /// phone-less and has no mirrored snapshot.
    private var standaloneFallback: some View {
        VStack(spacing: 12) {
            Text("No events synced from your iPhone.")
                .font(Brand.mono(11))
                .multilineTextAlignment(.center)
                .opacity(0.75)
            Button {
                requesting = true
                Task {
                    await store.requestCalendarAccess()
                    requesting = false
                }
            } label: {
                Text("Show my events")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.71, green: 0.54, blue: 0.34))
            .disabled(requesting)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
    }

    private var noEventsState: some View {
        VStack(spacing: 8) {
            Text(Brand.night)
                .font(.system(size: 30))
            Text("Nothing on the calendar.")
                .font(Brand.mono(11))
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One upcoming event, tinted by the home time-of-day color at its start.
struct EventCard: View {
    let event: UpcomingEvent
    let now: Date
    let homeTimeZone: TimeZone
    let aod: Bool
    let scheme: ColorScheme

    var body: some View {
        let hour = hourAtHome
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: scheme, aod: aod)
        let fg = Palette.foreground(forHour: hour, scheme: scheme, aod: aod)

        VStack(alignment: .leading, spacing: 5) {
            Text(event.title)
                .font(.system(size: 15, weight: .regular))
                .lineLimit(2)

            countdown(target: event.startDate)
                .font(.system(size: 22, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(timeRange)
                .font(Brand.mono(10))
                .opacity(0.78)
        }
        .foregroundStyle(fg)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func countdown(target: Date) -> some View {
        if target > now {
            Text(timerInterval: now ... target, countsDown: true)
        } else {
            Text("now")
        }
    }

    private var hourAtHome: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = homeTimeZone
        let c = cal.dateComponents([.hour, .minute], from: event.startDate)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private var timeRange: String {
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        fmt.timeZone = homeTimeZone
        let homeStr = fmt.format(event.startDate)
        if event.timezone.identifier != homeTimeZone.identifier {
            var ev = fmt
            ev.timeZone = event.timezone
            let abbr = event.timezone.abbreviation(for: event.startDate) ?? ""
            return "\(homeStr)  ·  \(ev.format(event.startDate)) \(abbr)"
        }
        return homeStr
    }
}
