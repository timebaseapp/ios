import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity — lock-screen card + Dynamic Island for the soonest
/// upcoming calendar event. Branded with the Timebase time-of-day gradient
/// at the event's start hour. Countdown ticks natively via
/// `Text(timerInterval:)`.
@available(iOSApplicationExtension 16.2, *)
struct EventCountdownLiveActivity: Widget {
    /// Deep link target for any Live Activity tap (lock-screen card +
    /// Dynamic Island expanded). Routes to the Up Next screen via
    /// `DeepLinkRouter` rather than dropping the user on the world clock.
    private static let tapDestination = URL(string: "timebase://upnext")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventCountdownAttributes.self) { context in
            LockScreenCard(context: context)
                .widgetURL(Self.tapDestination)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        GradientDot(date: context.state.start,
                                    tzId: context.attributes.eventTzIdentifier)
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("UP NEXT")
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Text(context.state.title)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    .widgetURL(Self.tapDestination)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // TimelineView with .explicit([start]) forces a single
                    // SwiftUI re-evaluation at event.start, which flips the
                    // conditional to "now". Without it the if-branch stays
                    // stuck and Text(timerInterval:) freezes at 00:00:00.
                    TimelineView(.explicit([Date(), context.state.start])) { timeline in
                        if context.state.start > timeline.date {
                            Text(timerInterval: timeline.date ... context.state.start,
                                 countsDown: true)
                                .monospacedDigit()
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("now")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        timeLabel("HOME",
                                  date: context.state.start,
                                  tzId: context.attributes.homeTzIdentifier)
                        Spacer()
                        timeLabel("EVENT",
                                  date: context.state.start,
                                  tzId: context.attributes.eventTzIdentifier)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .widgetURL(Self.tapDestination)
                }
            } compactLeading: {
                GradientDot(date: context.state.start,
                            tzId: context.attributes.eventTzIdentifier)
                    .frame(width: 14, height: 14)
            } compactTrailing: {
                // Apple framework bug — Text(_:style: .timer) and
                // Text(timerInterval:) request way more width than they
                // render in Live Activity contexts, stretching the pill.
                // Hard `.frame(maxWidth:)` clamp brings the trailing
                // region down to its actual visual width.
                Text(context.state.start, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
                    .minimumScaleFactor(0.7)
            } minimal: {
                GradientDot(date: context.state.start,
                            tzId: context.attributes.eventTzIdentifier)
            }
        }
    }

    @ViewBuilder
    private func timeLabel(_ caption: String, date: Date, tzId: String) -> some View {
        let tz = TimeZone(identifier: tzId) ?? .current
        VStack(alignment: .leading, spacing: 1) {
            Text(caption)
                .font(.system(size: 8, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(formatted(date: date, tz: tz))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    private func formatted(date: Date, tz: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
        fmt.timeZone = tz
        let abbr = tz.abbreviation(for: date) ?? ""
        let s = fmt.format(date)
        return abbr.isEmpty ? s : "\(s) \(abbr)"
    }
}

/// Lock-screen card — full-bleed time-of-day gradient with the event title
/// + ticking countdown + home/event time strip.
@available(iOSApplicationExtension 16.2, *)
private struct LockScreenCard: View {
    let context: ActivityViewContext<EventCountdownAttributes>

    var body: some View {
        let hour = fractionalHour(date: context.state.start,
                                  tzId: context.attributes.eventTzIdentifier)
        let grad = WidgetTimeColor.gradient(forHour: hour)
        let fg = WidgetTimeColor.foreground(forHour: hour)
        let secondary = fg.opacity(0.7)

        ZStack {
            LinearGradient(colors: grad, startPoint: .topLeading, endPoint: .bottomTrailing)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(secondary)
                    Text(context.state.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(fg)
                        .lineLimit(2)
                    // When the event is in the user's home timezone the
                    // two strings are identical — just show one. Otherwise
                    // show both so a remote-tz event reads at-a-glance.
                    let homeTzId = context.attributes.homeTzIdentifier
                    let eventTzId = context.attributes.eventTzIdentifier
                    HStack(spacing: 10) {
                        if homeTzId == eventTzId {
                            Text(formatted(date: context.state.start, tzId: eventTzId))
                        } else {
                            Text(formatted(date: context.state.start, tzId: homeTzId))
                            Text("·")
                            Text(formatted(date: context.state.start, tzId: eventTzId))
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(secondary)
                }
                // Flexible gap so the countdown gets pushed to the
                // trailing edge of the card. minLength: 12 guarantees a
                // little breathing room even with long titles.
                Spacer(minLength: 12)
                // TimelineView with .explicit([start]) forces a single
                // SwiftUI re-evaluation at event.start, so the conditional
                // can flip from countdown to "now". Without it the timer
                // freezes at 00:00:00 and "now" never renders.
                //
                // Explicit frame here too — Text(timerInterval:) in Live
                // Activity context reserves much wider intrinsic size than
                // the rendered digits. 130pt fits "1:23:45" at 30pt heavy.
                TimelineView(.explicit([Date(), context.state.start])) { timeline in
                    if context.state.start > timeline.date {
                        Text(timerInterval: timeline.date ... context.state.start,
                             countsDown: true)
                            .monospacedDigit()
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(fg)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: 130, alignment: .trailing)
                    } else {
                        Text("now")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(fg)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .activityBackgroundTint(Color.clear)
        .activitySystemActionForegroundColor(fg)
    }

    private func formatted(date: Date, tzId: String) -> String {
        let tz = TimeZone(identifier: tzId) ?? .current
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
        fmt.timeZone = tz
        let abbr = tz.abbreviation(for: date) ?? ""
        let s = fmt.format(date)
        return abbr.isEmpty ? s : "\(s) \(abbr)"
    }
}

/// Tiny circle filled with the Timebase time-of-day gradient at a moment in
/// time — used as our brand mark in the Dynamic Island.
private struct GradientDot: View {
    let date: Date
    let tzId: String

    var body: some View {
        let hour = fractionalHour(date: date, tzId: tzId)
        let grad = WidgetTimeColor.gradient(forHour: hour)
        Circle()
            .fill(LinearGradient(colors: grad,
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
    }
}

private struct CountdownText: View {
    let target: Date
    var body: some View {
        if target > Date() {
            Text(timerInterval: Date() ... target, countsDown: true)
        } else {
            Text("now")
        }
    }
}

private func fractionalHour(date: Date, tzId: String) -> Double {
    let tz = TimeZone(identifier: tzId) ?? .current
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.hour, .minute], from: date)
    return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
}
