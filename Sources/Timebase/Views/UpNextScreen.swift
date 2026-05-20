import SwiftUI

/// Dedicated calendar countdown screen. Each event card is tinted by the
/// time-of-day color at the **user's home timezone** when the event starts —
/// so the cards feel like part of *your* day, regardless of where the meeting
/// is scheduled.
struct UpNextScreen: View {
    @Environment(TimebaseStore.self) private var store
    @State private var showScheduler = false
    @State private var selectedEvent: UpcomingEvent?

    // Custom pull-to-refresh state. SwiftUI's `.refreshable` only gives the
    // system spinner — to show a branded gradient orb we track the scroll
    // over-scroll ourselves and drive the refresh from a threshold crossing.
    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var pullArmed = true

    private let scrollSpace = "upnext.scroll"
    private let pullThreshold: CGFloat = 86

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
                    // Zero-height marker — its minY in the scroll coordinate
                    // space is the live pull offset (positive = over-scrolled
                    // at the top, i.e. the user is pulling down).
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: UpNextScrollOffsetKey.self,
                                    value: geo.frame(in: .named(scrollSpace)).minY
                                )
                            }
                        )

                    LazyVStack(spacing: 12) {
                        UpNextSection(onTap: { event in
                            Haptics.buttonPressed()
                            selectedEvent = event
                        })

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
                    // While refreshing, hold the list down so the orb has
                    // clear space and never overlaps the first card.
                    .padding(.top, isRefreshing ? 54 : 0)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: scrollSpace)
                .onPreferenceChange(UpNextScrollOffsetKey.self) { value in
                    pullOffset = value
                    handlePull()
                }
                .overlay(alignment: .top) {
                    RefreshOrb(progress: pullProgress,
                               isRefreshing: isRefreshing,
                               hour: homeHour)
                        .offset(y: orbY)
                        .opacity((isRefreshing || pullOffset > 2) ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
        }
        .sheet(isPresented: $showScheduler) {
            SchedulerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: store.pendingShowScheduler) { _, pending in
            if pending {
                showScheduler = true
                store.pendingShowScheduler = false
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(upcoming: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Pull-to-refresh

    /// 0 → 1 as the pull approaches the trigger threshold.
    private var pullProgress: Double {
        Double(min(1, max(0, pullOffset / pullThreshold)))
    }

    /// Vertical position of the orb. While refreshing it sits in the
    /// held-open 54pt band; while pulling it rises with the over-scroll.
    private var orbY: CGFloat {
        isRefreshing ? 12 : max(0, pullOffset / 2 - 15)
    }

    /// Current fractional hour at the home city — sets the resting orb's
    /// time-of-day color.
    private var homeHour: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = store.homeCity?.timeZoneObject ?? .current
        let c = cal.dateComponents([.hour, .minute], from: Date())
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    /// Called on every scroll-offset change. Re-arms when the pull settles
    /// back near zero, and fires the refresh once when the threshold is
    /// crossed — the `pullArmed` flag stops it looping if the finger is
    /// still held past the threshold after a refresh completes.
    private func handlePull() {
        guard !isRefreshing else { return }
        if pullOffset < 10 { pullArmed = true }
        if pullArmed && pullOffset > pullThreshold {
            pullArmed = false
            triggerRefresh()
        }
    }

    private func triggerRefresh() {
        Haptics.buttonPressed()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRefreshing = true
        }
        Task {
            let start = Date()
            await store.refreshEvents()
            // Minimum on-screen time so the orb doesn't flash on a fast
            // refresh — let it spin through at least one partial "day".
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 0.9 {
                try? await Task.sleep(for: .seconds(0.9 - elapsed))
            }
            Haptics.refreshDone()
            withAnimation(.easeOut(duration: 0.3)) {
                isRefreshing = false
            }
        }
    }
}

/// Carries the scroll over-scroll distance up from the ScrollView.
private struct UpNextScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// The branded pull-to-refresh indicator: a small orb filled with the
/// time-of-day gradient. At rest it shows the home city's current hour and
/// scales in with the pull; while refreshing it cycles the gradient through
/// a full 24-hour day — sunrise, noon, dusk, night — on a 2.4s loop.
private struct RefreshOrb: View {
    let progress: Double
    let isRefreshing: Bool
    let hour: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if isRefreshing {
                TimelineView(.animation) { tl in
                    let secs = tl.date.timeIntervalSinceReferenceDate
                    let phase = (secs.truncatingRemainder(dividingBy: 2.4) / 2.4) * 24
                    orb(hour: phase)
                }
            } else {
                orb(hour: hour)
                    .scaleEffect(0.4 + 0.6 * progress)
            }
        }
        .frame(width: 34, height: 34)
    }

    private func orb(hour: Double) -> some View {
        let grad = TimeColor.backgroundGradient(forHour: hour, scheme: scheme)
        return Circle()
            .fill(LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom))
            // Top-left highlight so it reads as a lit sphere, not a flat disc.
            .overlay(
                Circle().fill(
                    RadialGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0)],
                        center: UnitPoint(x: 0.34, y: 0.30),
                        startRadius: 0, endRadius: 17)
                )
            )
            .overlay(Circle().stroke(.primary.opacity(0.10), lineWidth: 0.5))
            .frame(width: 30, height: 30)
            .shadow(color: (grad.last ?? .clear).opacity(0.55), radius: 7, y: 1)
    }
}

private struct UpNextSection: View {
    let onTap: (UpcomingEvent) -> Void
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
                    EventCard(event: event, now: tick, onTap: onTap)
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
    let onTap: (UpcomingEvent) -> Void
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
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { onTap(event) }
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
