import SwiftUI

/// Dedicated calendar countdown screen. Each event card is tinted by the
/// time-of-day color at the **user's home timezone** when the event starts —
/// so the cards feel like part of *your* day, regardless of where the meeting
/// is scheduled.
struct UpNextScreen: View {
    @Environment(TimebaseStore.self) private var store
    @State private var showScheduler = false

    var body: some View {
        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                TrafficLightsBar()

                ZStack {
                    ScreenHeader(title: "Up Next")
                    HStack {
                        Spacer()
                        Button {
                            Haptics.buttonPressed()
                            showScheduler = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                        }
                        .padding(.trailing, 14)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 18)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        UpNextSection()

                        Button {
                            Haptics.buttonPressed()
                            showScheduler = true
                        } label: {
                            Text("Plan a meeting")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 22)
                                .frame(height: 42)
                        }
                        .buttonStyle(SkeuomorphicPillButtonStyle())
                        .padding(.top, 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    // Real refresh — re-hits EventKit so events added in any
                    // calendar source (work, personal, shared) show up.
                    await store.refreshEvents()
                }
            }
        }
        .sheet(isPresented: $showScheduler) {
            SchedulerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct UpNextSection: View {
    @Environment(TimebaseStore.self) private var store
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !store.calendarAccessGranted {
                emptyPermissionState
            } else if store.upcomingEvents.isEmpty {
                noEventsState
            } else {
                ForEach(store.upcomingEvents) { event in
                    EventCard(event: event, now: tick)
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
        .padding(.vertical, 60)
    }

    private var noEventsState: some View {
        Text("Nothing on the calendar.")
            .font(.custom("DepartureMono-Regular", size: 14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }
}

private struct EventCard: View {
    let event: UpcomingEvent
    let now: Date
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let hourAtHome = fractionalHourAtHome
        let gradient = TimeColor.backgroundGradient(forHour: hourAtHome, scheme: colorScheme)
        let fg = TimeColor.foreground(forHour: hourAtHome, scheme: colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.system(size: 17, weight: .regular))

            CountdownText(target: event.startDate)

            HStack(spacing: 0) {
                Text(format(event.startDate, in: homeTimeZone))
                if event.timezone != homeTimeZone {
                    Text("  ·  ").foregroundStyle(fg.opacity(0.55))
                    Text(format(event.startDate, in: event.timezone))
                }
            }
            .font(.custom("DepartureMono-Regular", size: 11))
        }
        .foregroundStyle(fg)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                Image("grain")
                    .resizable(resizingMode: .tile)
                    .blendMode(.softLight)
                    .opacity(0.95)
                    .allowsHitTesting(false)
                Image("grain")
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.35)
                    .allowsHitTesting(false)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var homeTimeZone: TimeZone {
        store.homeCity?.timeZoneObject ?? .current
    }

    /// Hour-of-day at *home* when the event starts.
    private var fractionalHourAtHome: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = homeTimeZone
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
