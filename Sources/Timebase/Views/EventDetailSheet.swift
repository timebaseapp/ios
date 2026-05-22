import SwiftUI
import EventKit

/// Detail view for a calendar event. Fetches a fresh EKEvent from EventKit
/// so we get everything (location, notes, calendar, attendees, etc.) the
/// lightweight UpcomingEvent projection doesn't carry.
struct EventDetailSheet: View {
    let upcoming: UpcomingEvent

    @Environment(TimebaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var event: EKEvent?
    @State private var editingEvent: EKEvent?
    private let calendarService = EventKitService.shared

    var body: some View {
        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                SheetTrafficLights()
                content
            }
        }
        .onAppear {
            event = calendarService.event(withIdentifier: upcoming.id)
        }
        .sheet(item: $editingEvent) { ev in
            EventEditViewControllerRepresentable(
                event: ev,
                eventStore: calendarService.store
            ) { action in
                editingEvent = nil
                if action == .saved || action == .deleted {
                    Task {
                        await store.refreshEvents()
                        if action == .deleted {
                            dismiss()
                        } else {
                            event = calendarService.event(withIdentifier: upcoming.id)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title + live countdown — the marquee block
                VStack(alignment: .leading, spacing: 8) {
                    Text(upcoming.title)
                        .font(.custom("CrimsonText-SemiBold", size: 30))
                        .kerning(-0.3)
                        .multilineTextAlignment(.leading)

                    CountdownText(target: upcoming.startDate)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                section(title: "WHEN") {
                    detailRow(label: "Date", value: fullDate)
                    detailRow(label: "Home time", value: timeAtHome)
                    if upcoming.timezone != homeTimeZone {
                        detailRow(label: localTimeLabel, value: timeAtEvent)
                    }
                    detailRow(label: "Duration", value: durationText)
                }

                if let location = event?.location, !location.isEmpty {
                    section(title: "LOCATION") {
                        Button {
                            openLocation(location)
                        } label: {
                            HStack {
                                Text(location)
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let cal = event?.calendar {
                    section(title: "CALENDAR") {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 10, height: 10)
                            Text(cal.title)
                                .font(.system(size: 16))
                            Spacer()
                            Text(cal.source.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                    }
                }

                if let notes = event?.notes, !notes.isEmpty {
                    section(title: "NOTES") {
                        Text(notes)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let attendees = event?.attendees, !attendees.isEmpty {
                    section(title: "ATTENDEES") {
                        VStack(spacing: 0) {
                            ForEach(Array(attendees.enumerated()), id: \.offset) { _, attendee in
                                attendeeRow(attendee)
                            }
                        }
                    }
                }

                // Actions
                HStack(spacing: 10) {
                    if let ev = event, ev.calendar.allowsContentModifications {
                        Button {
                            Haptics.buttonPressed()
                            editingEvent = ev
                        } label: {
                            Text("Edit")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(SkeuomorphicPillButtonStyle())
                    }

                    Button {
                        Haptics.buttonPressed()
                        openInSystemCalendar()
                    } label: {
                        Text("Open in Calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(SkeuomorphicPillButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("DepartureMono-Regular", size: 11))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 16))
            Spacer()
            Text(value)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private func attendeeRow(_ attendee: EKParticipant) -> some View {
        let name = attendee.name ?? (attendee.url.absoluteString
            .replacingOccurrences(of: "mailto:", with: ""))
        let statusLabel = attendeeStatusLabel(attendee.participantStatus)
        return HStack {
            Text(name)
                .font(.system(size: 16))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(statusLabel)
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.primary.opacity(0.08)))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Formatting

    private var homeTimeZone: TimeZone {
        store.homeCity?.timeZoneObject ?? .current
    }

    private var fullDate: String {
        var fmt = Date.FormatStyle.dateTime
            .weekday(.wide)
            .month(.wide)
            .day()
        fmt.timeZone = homeTimeZone
        return fmt.format(upcoming.startDate)
    }

    private var timeAtHome: String {
        format(upcoming.startDate, in: homeTimeZone)
    }
    private var timeAtEvent: String {
        format(upcoming.startDate, in: upcoming.timezone)
    }
    private var localTimeLabel: String {
        let abbr = upcoming.timezone.abbreviation(for: upcoming.startDate) ?? "Local"
        return "\(abbr) time"
    }
    private func format(_ date: Date, in tz: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
        fmt.timeZone = tz
        return fmt.format(date)
    }

    private var durationText: String {
        let mins = Int(upcoming.endDate.timeIntervalSince(upcoming.startDate) / 60)
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h) hr" : "\(h)h \(m)m"
        }
        return "\(mins) min"
    }

    private func attendeeStatusLabel(_ status: EKParticipantStatus) -> String {
        switch status {
        case .accepted:  return "accepted"
        case .declined:  return "declined"
        case .tentative: return "tentative"
        case .pending:   return "pending"
        default:         return "—"
        }
    }

    // MARK: - Actions

    private func openInSystemCalendar() {
        // calshow: URL opens iOS Calendar at the given absolute time. The
        // numeric arg is seconds since 2001-01-01 (reference date).
        let refTime = upcoming.startDate.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(refTime)") {
            UIApplication.shared.open(url)
        }
    }

    private func openLocation(_ location: String) {
        // Try Maps URL first; falls back to a web search if Maps rejects.
        let q = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://maps.apple.com/?q=\(q)") {
            UIApplication.shared.open(url)
        }
    }
}
