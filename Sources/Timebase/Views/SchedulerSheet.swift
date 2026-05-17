import SwiftUI
import EventKit

/// "Plan a meeting" modal — pick participants (cities), scrub a time, see the
/// vibe for each city, choose duration, hand off to Apple's EKEventEditView.
struct SchedulerSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = Calendar.current.startOfDay(for: .now)
    @State private var scrubMinutesOfDay: Int = 9 * 60   // default 9:00 home time
    @State private var participantIds: [String] = []
    @State private var durationMinutes: Int = 30
    @State private var showAddCity = false
    @State private var draftEvent: EKEvent?
    @State private var initialScrub: Int = 0

    private let calendarService = EventKitService()

    private let durations = [15, 30, 45, 60, 90, 120]

    var body: some View {
        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .onAppear { setUpDefaults() }
        .sheet(isPresented: $showAddCity) {
            AddCitySheet()
        }
        .sheet(item: $draftEvent) { event in
            EventEditViewControllerRepresentable(
                event: event,
                eventStore: calendarService.store
            ) { action in
                draftEvent = nil
                if action == .saved {
                    Task {
                        await store.refreshEvents()
                        dismiss()
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Red traffic light to dismiss
            Button {
                Haptics.buttonPressed()
                dismiss()
            } label: {
                Circle()
                    .fill(Color(red: 1.0, green: 0.373, blue: 0.341))
                    .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(Color(red: 1.0, green: 0.741, blue: 0.180))
                .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                .frame(width: 13, height: 13)
            Circle()
                .fill(Color(red: 0.157, green: 0.788, blue: 0.251))
                .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                .frame(width: 13, height: 13)

            Spacer()

            Text("Plan a meeting")
                .font(.custom("CrimsonText-SemiBold", size: 20))

            Spacer()

            Button {
                Haptics.buttonPressed()
                openInCalendar()
            } label: {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(title.isEmpty || participants.isEmpty)
            .opacity((title.isEmpty || participants.isEmpty) ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 22) {
                titleField
                participantsSection
                whenSection
                vibeSection
                durationSection

                Button {
                    Haptics.buttonPressed()
                    openInCalendar()
                } label: {
                    Text("Continue to Calendar")
                        .font(.system(size: 15, weight: .heavy))
                        .padding(.horizontal, 26)
                        .frame(height: 46)
                }
                .buttonStyle(SkeuomorphicPillButtonStyle())
                .disabled(title.isEmpty || participants.isEmpty)
                .opacity((title.isEmpty || participants.isEmpty) ? 0.5 : 1)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var titleField: some View {
        TextField("Meeting title", text: $title)
            .font(.system(size: 17))
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.primary.opacity(0.10), lineWidth: 0.5)
                    )
            )
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("PARTICIPANTS")
            VStack(spacing: 0) {
                ForEach(participants) { city in
                    participantRow(city)
                }
                Button {
                    showAddCity = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add city")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    private func participantRow(_ city: City) -> some View {
        HStack(spacing: 8) {
            if city.id == store.homeCityId {
                Text("🏠").font(.system(size: 14))
            }
            Text(city.name).font(.system(size: 15))
            Spacer()
            Button {
                participantIds.removeAll { $0 == city.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WHEN")
            VStack(spacing: 0) {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                Divider().padding(.horizontal, 14)
                timeScrubber
                    .frame(height: 60)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    /// A vertical drag scrubber for the meeting time. Drag UP = later, DOWN
    /// = earlier. Snaps to 15-minute increments.
    private var timeScrubber: some View {
        HStack {
            Text("Time")
                .font(.system(size: 15))
            Spacer()
            Text(timeString)
                .font(.system(size: 22, weight: .heavy))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let dy = value.translation.height
                    // Lazy-capture initial when drag begins
                    if value.translation == .zero { return }
                    if initialScrub == 0 { initialScrub = scrubMinutesOfDay }
                    // 4pt per minute scrub feel
                    let deltaMin = Int(-dy / 4)
                    let raw = initialScrub + deltaMin
                    let snapped = ((raw + 7) / 15) * 15   // snap to nearest 15
                    scrubMinutesOfDay = max(0, min(24 * 60 - 1, snapped))
                }
                .onEnded { _ in
                    initialScrub = 0
                }
        )
    }

    private var timeString: String {
        let h = scrubMinutesOfDay / 60
        let m = scrubMinutesOfDay % 60
        let h12 = ((h + 11) % 12) + 1
        let suffix = h < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h12, m, suffix)
    }

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FOR EVERYONE")
            VStack(spacing: 0) {
                ForEach(participants) { city in
                    vibeRow(city)
                }
                if participants.isEmpty {
                    Text("Add participants to see the vibe")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    private func vibeRow(_ city: City) -> some View {
        let (cityHour, label, color, glyph) = vibe(for: city)
        let h12 = ((cityHour + 11) % 12) + 1
        let suffix = cityHour < 12 ? "AM" : "PM"

        return HStack(spacing: 10) {
            Text(city.name).font(.system(size: 15))
            Spacer()
            Text(String(format: "%d:00 %@", h12, suffix))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(glyph)
            Text(label)
                .font(.system(size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(color.opacity(0.18))
                )
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var durationSection: some View {
        HStack {
            Text("Duration").font(.system(size: 15))
            Spacer()
            Menu {
                ForEach(durations, id: \.self) { d in
                    Button {
                        durationMinutes = d
                    } label: {
                        Text(durationLabel(d))
                        if d == durationMinutes {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(durationLabel(durationMinutes))
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) hr" : "\(h)h \(m)m"
        }
        return "\(minutes) min"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.custom("DepartureMono-Regular", size: 11))
            .tracking(1.5)
            .foregroundStyle(.secondary)
    }

    // MARK: - Vibe + helpers

    private var participants: [City] {
        participantIds.compactMap { id in store.cities.first(where: { $0.id == id }) }
    }

    /// City hour for the chosen meeting time (in home tz, projected to city tz).
    private func hour(for city: City) -> Int {
        guard let home = store.homeCity else { return 12 }
        let homeOffset = home.timeZoneObject.secondsFromGMT()
        let cityOffset = city.timeZoneObject.secondsFromGMT()
        let diffMinutes = (cityOffset - homeOffset) / 60
        let total = scrubMinutesOfDay + diffMinutes
        let h = ((total / 60) % 24 + 24) % 24
        return h
    }

    private func vibe(for city: City) -> (hour: Int, label: String, color: Color, glyph: String) {
        let h = hour(for: city)
        switch h {
        case 9..<18:
            return (h, "working", .green, "☀")
        case 7..<9, 18..<21:
            return (h, "early/late", .orange, "⚠")
        default:
            return (h, "asleep", .gray, "🌙")
        }
    }

    // MARK: - Defaults / continue

    private func setUpDefaults() {
        if participantIds.isEmpty {
            participantIds = store.orderedCities.map { $0.id }
        }
    }

    private func openInCalendar() {
        // Build the absolute meeting start by combining `date` (the day) with
        // `scrubMinutesOfDay` interpreted in the user's home timezone.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = store.homeCity?.timeZoneObject ?? .current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = scrubMinutesOfDay / 60
        comps.minute = scrubMinutesOfDay % 60
        guard let start = cal.date(from: comps) else { return }
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let event = calendarService.makeDraftEvent(title: title, start: start, end: end)
        draftEvent = event
    }
}

// EKEvent needs Identifiable so we can drive a SwiftUI `.sheet(item:)`.
extension EKEvent: @retroactive Identifiable {
    public var id: String {
        eventIdentifier ?? "\(ObjectIdentifier(self).hashValue)"
    }
}
