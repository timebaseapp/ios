import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity — lock-screen card + Dynamic Island for the soonest
/// upcoming calendar event. Branded with the Timebase time-of-day gradient
/// at the event's start hour. Countdown ticks natively via
/// `Text(timerInterval:)`.
@available(iOSApplicationExtension 16.2, *)
struct EventCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventCountdownAttributes.self) { context in
            LockScreenCard(context: context)
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
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Same reasoning as compactTrailing — use the system
                    // `.timer` style; works reliably in expanded regions.
                    Text(context.state.start, style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
                }
            } compactLeading: {
                GradientDot(date: context.state.start,
                            tzId: context.attributes.eventTzIdentifier)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                // `Text(_:style: .timer)` is the reliable API for compact
                // Dynamic Island countdowns — `Text(timerInterval:)` has
                // a long-standing bug in this region where the content
                // renders zero-width / invisible. The system handles
                // vibrancy, sizing, and ticking automatically.
                Text(context.state.start, style: .timer)
                    .monospacedDigit()
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.trailing)
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

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(secondary)
                    Text(context.state.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(fg)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Text(formatted(date: context.state.start,
                                       tzId: context.attributes.homeTzIdentifier))
                        Text("·")
                        Text(formatted(date: context.state.start,
                                       tzId: context.attributes.eventTzIdentifier))
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(context.state.start, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(fg)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: false)
            }
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
