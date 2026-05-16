import SwiftUI
import EventKit

struct UpNextView: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !store.calendarAccessGranted {
                emptyState
            } else if store.upcomingEvents.isEmpty {
                noEventsState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.upcomingEvents) { event in
                            eventCard(event)
                            Divider()
                        }
                    }
                }
                .refreshable {
                    await store.refreshEvents()
                }
            }
        }
        .navigationTitle("")
        .onReceive(timer) { _ in tick = Date() }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("Grant Calendar access to see your day in countdowns.")
                .font(.system(size: 22, weight: .regular))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Allow") {
                Task { await store.requestCalendarAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var noEventsState: some View {
        Text("Nothing on the calendar.")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func eventCard(_ event: UpcomingEvent) -> some View {
        let now = tick
        let secondsToStart = event.startDate.timeIntervalSince(now)
        let hourAtEvent = fractionalHourAtEvent(event)
        let bg = Color(TimeColor.background(forHour: hourAtEvent, scheme: colorScheme).cgColor!)
        let fg = TimeColor.foreground(forHour: hourAtEvent, scheme: colorScheme)

        return VStack(alignment: .leading, spacing: 14) {
            Text(event.title)
                .font(.system(size: 22, weight: .regular))
            Text(TimebaseFormatters.relative(seconds: secondsToStart))
                .font(.system(size: 48, weight: .heavy))
                .monospacedDigit()
                .kerning(-1)
            HStack(spacing: 0) {
                Text(format(event.startDate, in: .current))
                Text("  ·  ").foregroundStyle(fg.opacity(0.55))
                Text(format(event.startDate, in: event.timezone))
            }
            .font(.system(size: 13))
        }
        .foregroundStyle(fg)
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
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

    private func fractionalHourAtEvent(_ event: UpcomingEvent) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = event.timezone
        let comps = cal.dateComponents([.hour, .minute], from: event.startDate)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }
}
