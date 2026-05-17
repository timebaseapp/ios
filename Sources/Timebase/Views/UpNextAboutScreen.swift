import SwiftUI

struct UpNextAboutScreen: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                TrafficLightsBar()

                ScrollView {
                    VStack(spacing: 0) {
                        UpNextSection()
                            .padding(.top, 8)
                            .padding(.bottom, 32)

                        Divider().padding(.horizontal, 28)

                        AboutCard()
                            .padding(.top, 24)
                    }
                }
            }
        }
    }
}

// Up Next section: countdown cards stacked vertically or empty state.
private struct UpNextSection: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !store.calendarAccessGranted {
                emptyPermissionState
            } else if store.upcomingEvents.isEmpty {
                noEventsState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.upcomingEvents) { event in
                        EventRow(event: event, now: tick)
                        Divider().padding(.horizontal, 28)
                    }
                }
            }
        }
        .onReceive(timer) { _ in tick = Date() }
    }

    private var emptyPermissionState: some View {
        VStack(spacing: 18) {
            Text("Connect Calendar to see your day in countdowns.")
                .font(.custom("DepartureMono-Regular", size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await store.requestCalendarAccess() }
            } label: {
                Text("Allow")
                    .font(.system(size: 13, weight: .heavy))
                    .padding(.horizontal, 20)
                    .frame(height: 38)
            }
            .buttonStyle(SkeuomorphicPillButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noEventsState: some View {
        Text("Nothing on the calendar.")
            .font(.custom("DepartureMono-Regular", size: 14))
            .foregroundStyle(.secondary)
            .padding(.vertical, 40)
    }
}

private struct EventRow: View {
    let event: UpcomingEvent
    let now: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let secondsToStart = event.startDate.timeIntervalSince(now)
        let hourAtEvent = fractionalHourAtEvent
        let bg = Color(TimeColor.background(forHour: hourAtEvent, scheme: colorScheme).cgColor!)
        let fg = TimeColor.foreground(forHour: hourAtEvent, scheme: colorScheme)

        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.system(size: 18, weight: .regular))
            Text(TimebaseFormatters.relative(seconds: secondsToStart))
                .font(.system(size: 36, weight: .heavy))
                .monospacedDigit()
                .kerning(-0.8)
            HStack(spacing: 0) {
                Text(format(event.startDate, in: .current))
                Text("  ·  ").foregroundStyle(fg.opacity(0.55))
                Text(format(event.startDate, in: event.timezone))
            }
            .font(.system(size: 11))
        }
        .foregroundStyle(fg)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
    }

    private var fractionalHourAtEvent: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = event.timezone
        let comps = cal.dateComponents([.hour, .minute], from: event.startDate)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    private func format(_ date: Date, in tz: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
        fmt.timeZone = tz
        let tzAbbr = tz.abbreviation(for: date) ?? ""
        let time = fmt.format(date)
        return tzAbbr.isEmpty ? time : "\(time) \(tzAbbr)"
    }
}
