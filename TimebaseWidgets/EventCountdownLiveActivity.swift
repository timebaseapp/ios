import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity — lock-screen card + Dynamic Island for the soonest
/// upcoming calendar event. Counts down natively via
/// `Text(timerInterval:)` so updates don't require frequent
/// `Activity.update`.
@available(iOSApplicationExtension 16.2, *)
struct EventCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventCountdownAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(target: context.state.start)
                        .monospacedDigit()
                        .font(.system(size: 14, weight: .heavy))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formattedTime(context.state.start,
                                           tzId: context.attributes.homeTzIdentifier))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedTime(context.state.start,
                                           tzId: context.attributes.eventTzIdentifier))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                }
            } compactLeading: {
                Image(systemName: "clock")
            } compactTrailing: {
                CountdownText(target: context.state.start)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .semibold))
            } minimal: {
                Image(systemName: "clock")
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct LockScreenCard: View {
    let context: ActivityViewContext<EventCountdownAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UP NEXT")
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Text(context.state.title)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
            CountdownText(target: context.state.start)
                .monospacedDigit()
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wraps `Text(timerInterval:)` with a fallback when the target is past.
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

private func formattedTime(_ date: Date, tzId: String) -> String {
    let tz = TimeZone(identifier: tzId) ?? .current
    var fmt = Date.FormatStyle.dateTime
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute(.twoDigits)
    fmt.timeZone = tz
    let abbr = tz.abbreviation(for: date) ?? ""
    let time = fmt.format(date)
    return abbr.isEmpty ? time : "\(time) \(abbr)"
}
