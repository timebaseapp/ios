import WidgetKit
import SwiftUI

// MARK: - Widget

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimebaseCountdown", provider: CountdownProvider()) { entry in
            CountdownEntryView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("Countdown to your next calendar events.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Timeline provider

struct CountdownEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, events: Self.placeholderEvents)
    }
    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        let events = WidgetStore.loadEvents()
        completion(CountdownEntry(date: .now, events: events.isEmpty ? Self.placeholderEvents : events))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let events = WidgetStore.loadEvents()
        // The Small widget uses native Text(timerInterval:) which ticks
        // every second by itself, but Medium / Large render a pre-formatted
        // "rich countdown" string (with d/h/m). For that to feel live, emit
        // a series of minute-spaced entries for the next hour. After that,
        // emit 5-minute spaced entries up to 6h — beyond which the deltas
        // change too slowly to matter and the system reload kicks in.
        let cal = Calendar.current
        let base = cal.date(bySetting: .second, value: 0, of: .now) ?? .now
        var entries: [CountdownEntry] = []
        for i in 0 ..< 60 {
            if let d = cal.date(byAdding: .minute, value: i, to: base) {
                entries.append(CountdownEntry(date: d, events: events))
            }
        }
        for i in stride(from: 65, through: 360, by: 5) {
            if let d = cal.date(byAdding: .minute, value: i, to: base) {
                entries.append(CountdownEntry(date: d, events: events))
            }
        }
        // Pick the soonest of [last entry + 1m, soonest event end] as the
        // reload trigger so passing events drop off promptly.
        let after = entries.last.map { $0.date.addingTimeInterval(60) } ?? .now
        let soonestEnd = events.first?.endDate ?? after
        let next = min(after, soonestEnd)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    /// Used when no EventKit data is available (preview / first launch).
    static let placeholderEvents: [WidgetEvent] = [
        WidgetEvent(
            id: "placeholder-1",
            title: "Standup",
            startDate: .now.addingTimeInterval(15 * 60),
            endDate: .now.addingTimeInterval(45 * 60),
            timezoneIdentifier: TimeZone.current.identifier
        ),
        WidgetEvent(
            id: "placeholder-2",
            title: "Design review",
            startDate: .now.addingTimeInterval(2 * 60 * 60),
            endDate: .now.addingTimeInterval(3 * 60 * 60),
            timezoneIdentifier: TimeZone.current.identifier
        )
    ]
}

// MARK: - Entry view

struct CountdownEntryView: View {
    let entry: CountdownEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:          CountdownSmallView(entry: entry)
        case .systemMedium:         CountdownMediumView(entry: entry)
        case .systemLarge:          CountdownLargeView(entry: entry)
        case .accessoryCircular:    CountdownAccessoryCircularView(entry: entry)
        case .accessoryRectangular: CountdownAccessoryRectView(entry: entry)
        case .accessoryInline:      CountdownAccessoryInlineView(entry: entry)
        default:                    CountdownSmallView(entry: entry)
        }
    }
}

// MARK: - System

private struct CountdownSmallView: View {
    let entry: CountdownEntry

    var body: some View {
        let event = entry.events.first
        Color.clear
            .containerBackground(for: .widget) {
                ZStack {
                    eventBackground(for: event)
                    if let event {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UP NEXT")
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(event.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Spacer()
                            countdownText(target: event.startDate)
                                .font(.system(size: 26, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    } else {
                        emptyState
                    }
                }
            }
            .widgetURL(URL(string: "timebase://upnext"))
    }
}

private struct CountdownMediumView: View {
    let entry: CountdownEntry

    var body: some View {
        let events = Array(entry.events.prefix(3))
        Color.clear
            .containerBackground(for: .widget) {
                if events.isEmpty {
                    ZStack {
                        eventBackground(for: nil)
                        emptyState
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(events, id: \.id) { event in
                            countdownEventStrip(event: event, now: entry.date)
                        }
                    }
                }
            }
            .widgetURL(URL(string: "timebase://upnext"))
    }
}

private struct CountdownLargeView: View {
    let entry: CountdownEntry

    var body: some View {
        let events = Array(entry.events.prefix(6))
        Color.clear
            .containerBackground(for: .widget) {
                if events.isEmpty {
                    ZStack {
                        eventBackground(for: nil)
                        emptyState
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(events, id: \.id) { event in
                            countdownEventStrip(event: event, now: entry.date)
                        }
                    }
                }
            }
            .widgetURL(URL(string: "timebase://upnext"))
    }
}

// MARK: - Lock screen

private struct CountdownAccessoryCircularView: View {
    let entry: CountdownEntry
    var body: some View {
        if let event = entry.events.first {
            Gauge(value: 0) {
                Text("Up")
            } currentValueLabel: {
                countdownText(target: event.startDate)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "timebase://upnext"))
        } else {
            Image(systemName: "calendar")
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "timebase://upnext"))
        }
    }
}

private struct CountdownAccessoryRectView: View {
    let entry: CountdownEntry
    var body: some View {
        Group {
            if let event = entry.events.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UP NEXT")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    countdownText(target: event.startDate)
                        .font(.system(size: 13, weight: .heavy))
                        .monospacedDigit()
                }
            } else {
                Text("No upcoming events")
                    .font(.system(size: 12))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "timebase://upnext"))
    }
}

private struct CountdownAccessoryInlineView: View {
    let entry: CountdownEntry
    var body: some View {
        if let event = entry.events.first {
            // Inline accessory is a single line of Text — concat title +
            // native timer.
            (Text(event.title) + Text(" · ") +
             Text(timerInterval: Date() ... max(event.startDate, .now.addingTimeInterval(1)),
                  countsDown: true))
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "timebase://upnext"))
        } else {
            Text("No upcoming events")
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "timebase://upnext"))
        }
    }
}

// MARK: - Shared bits

@ViewBuilder
private func eventBackground(for event: WidgetEvent?) -> some View {
    let hour = event.map {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = $0.timeZone
        let comps = cal.dateComponents([.hour, .minute], from: $0.startDate)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    } ?? 12.0
    let grad = WidgetTimeColor.gradient(forHour: hour)
    LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
}

@ViewBuilder
private func eventRow(event: WidgetEvent, primary: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: primary ? 15 : 13, weight: primary ? .semibold : .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(eventTimeRange(event: event))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        Spacer(minLength: 6)
        countdownText(target: event.startDate)
            .font(.system(size: primary ? 18 : 14, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(.white)
    }
}

/// One full-bleed gradient strip per event — mirrors WorldClockWidget's
/// per-city row pattern. Title left, countdown right.
@ViewBuilder
private func countdownEventStrip(event: WidgetEvent, now: Date) -> some View {
    let h = hourOfDay(event.startDate, tz: event.timeZone)
    let grad = WidgetTimeColor.gradient(forHour: h)
    let fg = WidgetTimeColor.foreground(forHour: h)
    ZStack {
        LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(eventTimeRange(event: event))
                    .font(.system(size: 10, design: .monospaced))
                    .opacity(0.72)
            }
            Spacer(minLength: 8)
            Text(richCountdown(target: event.startDate, now: now))
                .font(.system(size: 16, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .frame(alignment: .trailing)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 14)
    }
    .frame(maxHeight: .infinity)
}

@ViewBuilder
private func countdownText(target: Date) -> some View {
    if target > Date() {
        Text(timerInterval: Date() ... target, countsDown: true)
    } else {
        Text("now")
    }
}

private func hourOfDay(_ date: Date, tz: TimeZone) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.hour, .minute], from: date)
    return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
}

/// "12d 4h" / "3h 14m" / "47m" / "30s" / "now" — `now` is the entry's
/// reference date, so the same string is correct whether the widget is
/// rendering an entry for current wall time or a future scheduled entry.
private func richCountdown(target: Date, now: Date) -> String {
    let interval = target.timeIntervalSince(now)
    if interval < 60 { return interval < 1 ? "now" : "\(Int(interval))s" }
    let total = Int(interval)
    let days = total / 86400
    let hours = (total % 86400) / 3600
    let minutes = (total % 3600) / 60
    if days >= 1 {
        return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
    }
    if hours >= 1 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
}

private func eventTimeRange(event: WidgetEvent) -> String {
    var fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
    fmt.timeZone = event.timeZone
    return fmt.format(event.startDate)
}

@ViewBuilder
private var emptyState: some View {
    VStack(spacing: 6) {
        Image(systemName: "calendar")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.85))
        Text("No upcoming events")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.85))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
