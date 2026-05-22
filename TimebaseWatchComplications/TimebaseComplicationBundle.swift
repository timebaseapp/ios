import WidgetKit
import SwiftUI

/// The Timebase watchOS complication bundle.
///
/// Two widgets, both `accessory*`-family — one tappable, deep-linking world
/// clock and the Live Activity continuity config. WidgetKit selects the
/// supported family per face slot, so a single `WorldClockComplication`
/// covers all four families the SCOPE calls for.
@main
struct TimebaseComplicationBundle: WidgetBundle {
    var body: some Widget {
        WorldClockComplication()
        // A live next-event countdown for the Smart Stack — works standalone,
        // no iPhone required.
        NextEventWidget()
        // The Live Activity continuity config is included only when the
        // watchOS SDK provides `ActivityKit`. When it is absent, watchOS
        // still surfaces the iPhone's activity automatically — see
        // `EventCountdownLiveActivity.swift`.
        #if canImport(ActivityKit)
        EventCountdownLiveActivity()
        #endif
    }
}

/// The four-family world clock complication. Every family is a small, honest,
/// tappable summary that deep-links into the app.
struct WorldClockComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "cc.timebase.watch.worldclock",
                            provider: TimebaseProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Timebase")
        .description("Your home city, its time-of-day color, and your next event.")
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Xcode canvas previews
//
// Complications render on a watch face, so they can't be screenshotted from
// the running app. Open this file in Xcode to see every family in the canvas.

#Preview("Corner", as: .accessoryCorner) {
    WorldClockComplication()
} timeline: {
    TimebaseProvider.placeholderEntry
}

#Preview("Circular", as: .accessoryCircular) {
    WorldClockComplication()
} timeline: {
    TimebaseProvider.placeholderEntry
}

#Preview("Rectangular", as: .accessoryRectangular) {
    WorldClockComplication()
} timeline: {
    TimebaseProvider.placeholderEntry
}

#Preview("Inline", as: .accessoryInline) {
    WorldClockComplication()
} timeline: {
    TimebaseProvider.placeholderEntry
}
