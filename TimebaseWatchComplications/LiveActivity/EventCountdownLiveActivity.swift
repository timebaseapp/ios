import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// =====================================================================
//  Live Activity continuity.
//
//  When the paired iPhone runs an `EventCountdownAttributes` activity for
//  an upcoming event, watchOS surfaces it in the Smart Stack and
//  side-of-display AUTOMATICALLY — Apple handles the transport and the
//  presentation. The only hard requirement is that the `ActivityAttributes`
//  type is available on the Watch side, which the vendored
//  `EventCountdownAttributes.swift` provides.
//
//  When the watchOS SDK slice ships `ActivityKit`, this file adds a tuned
//  `ActivityConfiguration` so the countdown matches the Timebase brand.
//  When it does not, the system still surfaces the iPhone activity with its
//  default styling — no watch-side code is needed for the feature to work.
// =====================================================================

#if canImport(ActivityKit)

/// Brand-tuned watch rendering of the iPhone's Timebase Live Activity.
struct EventCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventCountdownAttributes.self) { context in
            countdownView(for: context)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: gradient(for: context),
                        startPoint: .top, endPoint: .bottom
                    )
                }
        } dynamicIsland: { context in
            // The watch does not render a Dynamic Island; ActivityKit still
            // requires the branch. Kept minimal.
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    countdownView(for: context)
                }
            } compactLeading: {
                Text(Brand.goldenHour)
            } compactTrailing: {
                Text(timerInterval: timerRange(context.state.start), countsDown: true)
                    .monospacedDigit()
            } minimal: {
                Text(timerInterval: timerRange(context.state.start), countsDown: true)
                    .monospacedDigit()
            }
        }
    }

    private func countdownView(
        for context: ActivityViewContext<EventCountdownAttributes>
    ) -> some View {
        let hour = startHourAtHome(context)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)
        return VStack(alignment: .leading, spacing: 3) {
            Text("UP NEXT")
                .font(Brand.mono(9))
                .tracking(1.4)
                .opacity(0.7)
            Text(context.state.title)
                .font(Brand.serif(16))
                .lineLimit(1)
            Text(timerInterval: timerRange(context.state.start), countsDown: true)
                .font(.system(size: 22, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }

    private func timerRange(_ start: Date) -> ClosedRange<Date> {
        let now = Date()
        return now ... max(start, now.addingTimeInterval(1))
    }

    private func gradient(
        for context: ActivityViewContext<EventCountdownAttributes>
    ) -> [Color] {
        Palette.backgroundGradient(forHour: startHourAtHome(context), scheme: .dark)
    }

    /// Time-of-day hour at the home timezone when the event starts — tints
    /// the activity card by *your* day, mirroring Up Next.
    private func startHourAtHome(
        _ context: ActivityViewContext<EventCountdownAttributes>
    ) -> Double {
        let tz = TimeZone(identifier: context.attributes.homeTzIdentifier) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: context.state.start)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
}

#endif
