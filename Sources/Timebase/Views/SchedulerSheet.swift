import SwiftUI
import EventKit

/// "Plan a meeting" modal — pick participants (cities), choose date+time
/// natively, see how it lands for each participant, hand off to Apple's
/// EKEventEditView for the rest (notes, invitees, recurrence, location).
struct SchedulerSheet: View {
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    /// The meeting time as an absolute Date — interpreted in the anchor
    /// city's timezone for display. SwiftUI re-renders dependents instantly
    /// when this changes, so the "For everyone" section never lags.
    @State private var meetingTime: Date = defaultMeetingTime()
    @State private var participantIds: [String] = []
    /// Which participant the date/time picker is anchored to. Defaults to
    /// the user's home city, but can be set to any participant — useful
    /// when you're planning around someone else's wake hours.
    @State private var anchorCityId: String?
    @State private var durationMinutes: Int = 30
    @State private var showPicker = false
    @State private var draftEvent: EKEvent?
    @FocusState private var titleFocused: Bool

    @AppStorage("timebase.scheduler.anchorHintDismissed") private var anchorHintDismissed = false

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
        .sheet(isPresented: $showPicker) {
            ParticipantPickerSheet(
                excludedIds: Set(participantIds),
                onPick: { city in
                    if !participantIds.contains(city.id) {
                        participantIds.append(city.id)
                    }
                }
            )
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
                        // Saving a planned meeting is a completed, valuable
                        // interaction — the strongest moment to ask for a
                        // review. ClockListView watches pendingReviewPrompt
                        // and surfaces the system prompt.
                        store.maybeRequestReview(trigger: .meetingScheduled)
                        dismiss()
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Plan a meeting")
                .font(.custom("CrimsonText-SemiBold", size: 22))

            HStack {
                Spacer()
                Button {
                    Haptics.buttonPressed()
                    openInCalendar()
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                }
                .disabled(title.isEmpty || participants.isEmpty)
                .opacity((title.isEmpty || participants.isEmpty) ? 0.4 : 1)
            }
            .padding(.trailing, 18)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
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

                VStack(spacing: 12) {
                    // "Check with them" — share the proposed time so people
                    // can confirm BEFORE it's committed to a calendar. Shown
                    // once there are ≥2 cities (one city = nothing to
                    // coordinate). Doesn't require a meeting title.
                    if participants.count >= 2 {
                        ShareLink(item: shareText) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Check with them")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 22)
                            .frame(height: 42)
                            .overlay(
                                Capsule().stroke(.primary.opacity(0.18), lineWidth: 1)
                            )
                        }
                    }

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
                }
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        // Tap outside any field to dismiss the keyboard
        .onTapGesture { titleFocused = false }
    }

    private var titleField: some View {
        TextField("Meeting title", text: $title)
            .font(.system(size: 17))
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { titleFocused = false }
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
                    titleFocused = false
                    showPicker = true
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
            if !anchorHintDismissed && participants.count >= 2 {
                Text("Tap a participant to anchor the meeting around their timezone.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func participantRow(_ city: City) -> some View {
        let isAnchor = (city.id == effectiveAnchorCityId)
        return HStack(spacing: 8) {
            if city.id == store.homeCityId {
                Text("🏠").font(.system(size: 14))
            }
            Text(city.name).font(.system(size: 15))
            if isAnchor {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            Spacer()
            Button {
                participantIds.removeAll { $0 == city.id }
                // If we just removed the current anchor, clear it so
                // effectiveAnchorCityId falls back to home / first.
                if anchorCityId == city.id {
                    anchorCityId = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            isAnchor
            ? Color.primary.opacity(0.04)
            : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.buttonPressed()
            anchorCityId = city.id
            anchorHintDismissed = true
        }
    }

    /// Native iOS date + time picker — compact style. Tap either to bring up
    /// the wheel/calendar in a popover. Two rows: date row, time row.
    /// The picker reads/writes in the *anchor* timezone (not necessarily
    /// the user's home), so "10 AM" means 10 AM at the anchored city.
    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sectionHeader("WHEN")
                if let anchorName = anchorCityName, anchorCityId != store.homeCityId {
                    Text("· in \(anchorName)")
                        .font(.custom("DepartureMono-Regular", size: 10))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                if isWeekend {
                    Text("· \(weekdayName) — heads up, it's the weekend")
                        .font(.custom("DepartureMono-Regular", size: 10))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            VStack(spacing: 0) {
                DatePicker("Date",
                           selection: $meetingTime,
                           displayedComponents: .date)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                Divider().padding(.horizontal, 14)
                DatePicker("Time",
                           selection: $meetingTime,
                           displayedComponents: .hourAndMinute)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
            }
            .environment(\.timeZone, anchorTimeZone)
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

    private var isWeekend: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = anchorTimeZone
        let weekday = cal.component(.weekday, from: meetingTime)
        return weekday == 1 || weekday == 7   // Sunday=1, Saturday=7
    }

    private var weekdayName: String {
        var fmt = Date.FormatStyle.dateTime.weekday(.wide)
        fmt.timeZone = anchorTimeZone
        return fmt.format(meetingTime)
    }

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FOR EVERYONE")
            VStack(spacing: 0) {
                if participants.isEmpty {
                    HStack {
                        Text("Add a participant to see the vibe")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                } else {
                    ForEach(participants) { city in
                        vibeRow(city)
                    }
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
        let (label, color, glyph) = vibe(for: city)
        return HStack(spacing: 10) {
            Text(city.name).font(.system(size: 15))
            Spacer()
            Text(localTimeString(for: city))
                .font(.system(size: 14))
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

    // MARK: - Helpers

    private var homeTimeZone: TimeZone {
        store.homeCity?.timeZoneObject ?? .current
    }

    /// The id of the city the date picker is anchored to. If the user
    /// explicitly picked one and it's still in the participant list, use
    /// that. Otherwise fall back to home, then first participant.
    private var effectiveAnchorCityId: String? {
        if let id = anchorCityId, participantIds.contains(id) { return id }
        if let homeId = store.homeCityId, participantIds.contains(homeId) { return homeId }
        return participantIds.first
    }

    private var anchorCity: City? {
        guard let id = effectiveAnchorCityId else { return nil }
        return store.cities.first(where: { $0.id == id })
            ?? store.cityDatabase.first(where: { $0.id == id })
    }

    private var anchorTimeZone: TimeZone {
        anchorCity?.timeZoneObject ?? homeTimeZone
    }

    private var anchorCityName: String? {
        anchorCity?.name
    }

    private var participants: [City] {
        participantIds.compactMap { id in
            store.cities.first(where: { $0.id == id }) ??
            store.cityDatabase.first(where: { $0.id == id })
        }
    }

    /// Local hour at the city's timezone for the absolute meeting time.
    private func hour(for city: City) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZoneObject
        return cal.component(.hour, from: meetingTime)
    }

    private func localTimeString(for city: City) -> String {
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
        fmt.timeZone = city.timeZoneObject
        return fmt.format(meetingTime)
    }

    private func vibe(for city: City) -> (label: String, color: Color, glyph: String) {
        let h = hour(for: city)
        switch h {
        case 23, 0..<6:
            return ("asleep", .gray, "🌙")
        case 6..<9:
            return ("waking up", .orange, "☕")
        case 9..<18:
            return ("working", .green, "☀")
        default:                       // 18 ..< 23
            return ("winding down", .orange, "🌇")
        }
    }

    // MARK: - Share text ("Check with them")

    /// The text put on the iOS share sheet. Two tones, chosen in
    /// Settings → Preferences → Share style.
    private var shareText: String {
        guard let anchor = anchorCity else { return "" }
        // Anchor city leads; the rest follow in participant order.
        let ordered = [anchor] + participants.filter { $0.id != anchor.id }
        let anchorDay = calendarDayKey(for: anchor)
        let titlePrefix = title.isEmpty ? "" : "\(title) — "

        switch store.settings.shareStyle {
        case .cityByCity:
            var datePhrase = Date.FormatStyle.dateTime
                .weekday(.abbreviated).month(.abbreviated).day()
            datePhrase.timeZone = anchor.timeZoneObject
            var lines = ["\(titlePrefix)does \(datePhrase.format(meetingTime)) work?", ""]
            for c in ordered {
                var line = "\(shareGlyph(for: c)) \(c.name) · \(cleanTime(for: c))"
                if calendarDayKey(for: c) != anchorDay {
                    line += " \(weekdayAbbr(for: c))"
                }
                lines.append(line)
            }
            return lines.joined(separator: "\n")

        case .oneSentence:
            var datePhrase = Date.FormatStyle.dateTime
                .weekday(.wide).month(.wide).day()
            datePhrase.timeZone = anchor.timeZoneObject
            var sentence = "\(titlePrefix)how's \(datePhrase.format(meetingTime)) "
                + "at \(cleanTime(for: anchor)) in \(anchor.name)?"
            let others = Array(ordered.dropFirst())
            if !others.isEmpty {
                let pieces = others.map { c -> String in
                    var p = "\(cleanTime(for: c)) in \(c.name)"
                    if calendarDayKey(for: c) != anchorDay {
                        p += " (\(weekdayAbbr(for: c)))"
                    }
                    return p
                }
                sentence += " That's " + naturalList(pieces) + "."
            }
            return sentence
        }
    }

    /// 🌙 ☕ ☀️ 🌇 — forces the emoji presentation of the sun glyph so it
    /// renders in colour in a chat, not as a black text-style character.
    private func shareGlyph(for city: City) -> String {
        let g = vibe(for: city).glyph
        return g == "☀" ? "☀️" : g
    }

    /// "8 AM" / "8:30 AM" / "20:00" — drops the ":00" on whole hours in
    /// 12-hour mode; keeps it in 24-hour mode where a bare hour reads
    /// oddly. Respects the user's hour preference.
    private func cleanTime(for city: City) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZoneObject
        let comps = cal.dateComponents([.hour, .minute], from: meetingTime)
        let h = comps.hour ?? 0, m = comps.minute ?? 0

        let use24: Bool
        switch store.settings.hourPreference {
        case .on:  use24 = true
        case .off: use24 = false
        case .system:
            let cycle = Locale.current.hourCycle
            use24 = cycle == .zeroToTwentyThree || cycle == .oneToTwentyFour
        }

        if use24 {
            return String(format: "%d:%02d", h, m)
        }
        let period = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(h12) \(period)"
                      : "\(h12):\(String(format: "%02d", m)) \(period)"
    }

    /// YYYY-MM-DD in the city's timezone — used to detect a date rollover.
    private func calendarDayKey(for city: City) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZoneObject
        let c = cal.dateComponents([.year, .month, .day], from: meetingTime)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func weekdayAbbr(for city: City) -> String {
        var fmt = Date.FormatStyle.dateTime.weekday(.abbreviated)
        fmt.timeZone = city.timeZoneObject
        return fmt.format(meetingTime)
    }

    /// "a" → "a", "a, b" → "a and b", "a, b, c" → "a, b, and c".
    private func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ")
                        + ", and " + (items.last ?? "")
        }
    }

    // MARK: - Defaults / continue

    private func setUpDefaults() {
        #if DEBUG
        if MarketingCapture.isActive {
            if let pending = MarketingCapture.pendingSchedulerCityIds {
                participantIds = pending
            } else if let homeId = store.homeCityId {
                participantIds = [homeId]
            }
            if let t = MarketingCapture.pendingSchedulerMeetingTime {
                meetingTime = t
            }
            if let s = MarketingCapture.pendingSchedulerTitle {
                title = s
            }
            return
        }
        #endif
        if participantIds.isEmpty, let homeId = store.homeCityId {
            participantIds = [homeId]
        }
        // Default anchor to home, if home is one of the participants.
        if anchorCityId == nil {
            anchorCityId = store.homeCityId
        }
    }

    private func openInCalendar() {
        titleFocused = false
        let end = meetingTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let event = calendarService.makeDraftEvent(title: title, start: meetingTime, end: end)
        draftEvent = event
    }

    /// Default meeting time: today at 09:00 in the current timezone (home tz
    /// might not be set yet at View init).
    private static func defaultMeetingTime() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = 9
        comps.minute = 0
        return cal.date(from: comps) ?? now
    }
}

// EKEvent needs Identifiable so we can drive a SwiftUI `.sheet(item:)`.
extension EKEvent: @retroactive Identifiable {
    public var id: String {
        eventIdentifier ?? "\(ObjectIdentifier(self).hashValue)"
    }
}
