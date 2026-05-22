import WidgetKit
import SwiftUI

/// A live countdown to the next event, built for the watchOS Smart Stack.
///
/// Unlike the world-clock complication, this works fully standalone — no
/// iPhone, no Live Activity required — and uses a self-ticking
/// `Text(timerInterval:)`. `accessoryRectangular` is the family the Smart
/// Stack renders; `relevance` lets the stack surface it as an event nears.
struct NextEventWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "cc.timebase.watch.nextevent",
                            provider: NextEventProvider()) { entry in
            NextEventView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("A live countdown to your next event.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: UpcomingEvent?
    let relevance: TimelineEntryRelevance?
}

/// Self-contained provider — reads the mirrored event snapshot directly so
/// the widget never depends on the app being launched.
struct NextEventProvider: TimelineProvider {
    private let reader = TimebaseSharedReader()

    func placeholder(in context: Context) -> NextEventEntry {
        NextEventEntry(
            date: .now,
            event: UpcomingEvent(id: "ph", title: "Standup",
                                 startDate: .now.addingTimeInterval(1500),
                                 endDate: .now.addingTimeInterval(3300),
                                 timezoneIdentifier: TimeZone.current.identifier),
            relevance: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEventEntry) -> Void) {
        reader.synchronize()
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEventEntry>) -> Void) {
        reader.synchronize()
        let cal = Calendar.current
        let base = cal.date(bySetting: .second, value: 0, of: .now) ?? .now
        var entries: [NextEventEntry] = []
        for i in 0 ..< 30 {
            guard let d = cal.date(byAdding: .minute, value: i, to: base) else { continue }
            entries.append(entry(at: d))
        }
        let refresh = cal.date(byAdding: .minute, value: 30, to: base) ?? .now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(at date: Date) -> NextEventEntry {
        let event = reader.loadMirroredEvents().first { $0.endDate > date }
        return NextEventEntry(date: date, event: event,
                              relevance: relevance(for: event, at: date))
    }

    /// Surfaces the widget in the Smart Stack as an event approaches — the
    /// score rises over the three hours before it starts.
    private func relevance(for event: UpcomingEvent?, at date: Date) -> TimelineEntryRelevance? {
        guard let event else { return nil }
        let secondsUntil = event.startDate.timeIntervalSince(date)
        guard secondsUntil > -3600, secondsUntil < 3 * 3600 else { return nil }
        let score = Float(max(0, min(1, 1 - secondsUntil / (3 * 3600))))
        return TimelineEntryRelevance(score: score * 100,
                                      duration: max(0, secondsUntil) + 1800)
    }
}

struct NextEventView: View {
    let entry: NextEventEntry

    var body: some View {
        Group {
            if let event = entry.event {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.6)
                    if event.startDate > entry.date {
                        Text(timerInterval: entry.date ... event.startDate, countsDown: true)
                            .font(.system(size: 21, weight: .heavy))
                            .monospacedDigit()
                    } else {
                        Text("now")
                            .font(.system(size: 21, weight: .heavy))
                    }
                    Text(event.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.6)
                    Text("Nothing on the calendar")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "timebase://upnext"))
    }
}

// MARK: - Xcode canvas preview
//
// Open this file in Xcode to see the Smart Stack widget — scrub the timeline
// to see both the live-countdown and empty-calendar states.

#Preview("Up Next", as: .accessoryRectangular) {
    NextEventWidget()
} timeline: {
    NextEventEntry(
        date: .now,
        event: UpcomingEvent(id: "preview", title: "Design review",
                             startDate: .now.addingTimeInterval(25 * 60),
                             endDate: .now.addingTimeInterval(85 * 60),
                             timezoneIdentifier: TimeZone.current.identifier),
        relevance: nil
    )
    NextEventEntry(date: .now, event: nil, relevance: nil)
}
