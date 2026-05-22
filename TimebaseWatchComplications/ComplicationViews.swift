import SwiftUI
import WidgetKit

/// Routes a `TimebaseEntry` to the right view for the active accessory family.
struct ComplicationEntryView: View {
    let entry: TimebaseEntry
    @Environment(\.widgetFamily) private var family
    /// Always-On Display — drives the muted gradient variant.
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        switch family {
        case .accessoryCorner:      CornerComplication(entry: entry, aod: aod)
        case .accessoryCircular:    CircularComplication(entry: entry, aod: aod)
        case .accessoryRectangular: RectangularComplication(entry: entry, aod: aod)
        case .accessoryInline:      InlineComplication(entry: entry)
        default:                    CircularComplication(entry: entry, aod: aod)
        }
    }
}

// MARK: - Corner
//
// Home city time + a tiny next-event countdown tucked into the curve.

struct CornerComplication: View {
    let entry: TimebaseEntry
    let aod: Bool

    var body: some View {
        let city = entry.homeCity
        let tz = city?.timeZoneObject ?? .current
        Text(ComplicationFormat.time(entry.date, tz: tz, pref: entry.settings.hourPreference))
            .font(.system(size: 17, weight: .heavy))
            .monospacedDigit()
            .widgetLabel {
                if let ev = entry.nextEvent {
                    Text("\(ComplicationFormat.shortName(ev.title, max: 12)) · \(ComplicationFormat.countdown(to: ev.startDate, from: entry.date))")
                } else {
                    Text(city?.name ?? "Timebase")
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "timebase://city/\(city?.id ?? "")"))
    }
}

// MARK: - Circular  (THE HERO)
//
// Home city time on the time-of-day OKLCH gradient dial. This is the
// ambient-billboard complication — the dial color drifts through the day.

struct CircularComplication: View {
    let entry: TimebaseEntry
    let aod: Bool

    var body: some View {
        let city = entry.homeCity
        let tz = city?.timeZoneObject ?? .current
        let hour = ComplicationFormat.fractionalHour(in: tz, at: entry.date)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark, aod: aod)
        let fg = Palette.foreground(forHour: hour, scheme: .dark, aod: aod)

        ZStack {
            VStack(spacing: 0) {
                Text(Brand.emoji(forHour: hour))
                    .font(.system(size: 11))
                Text(ComplicationFormat.time(entry.date, tz: tz,
                                             pref: entry.settings.hourPreference))
                    .font(.system(size: 15, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(ComplicationFormat.shortName(city?.name ?? "—", max: 7))
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.85)
            }
            .foregroundStyle(fg)
            .padding(2)
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
        }
        .widgetURL(URL(string: "timebase://city/\(city?.id ?? "")"))
    }
}

// MARK: - Rectangular
//
// Home time, delta to a second city, and a one-line next-event summary.

struct RectangularComplication: View {
    let entry: TimebaseEntry
    let aod: Bool

    var body: some View {
        let ordered = entry.orderedCities
        let home = entry.homeCity
        let homeTz = home?.timeZoneObject ?? .current
        let second = ordered.first { $0.id != home?.id }

        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(Brand.home).font(.system(size: 10))
                Text(ComplicationFormat.shortName(home?.name ?? "—", max: 10))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 2)
                Text(ComplicationFormat.time(entry.date, tz: homeTz,
                                             pref: entry.settings.hourPreference))
                    .font(.system(size: 13, weight: .heavy))
                    .monospacedDigit()
            }
            if let second {
                HStack(spacing: 4) {
                    Text(ComplicationFormat.shortName(second.name, max: 10))
                        .font(.system(size: 12))
                    Spacer(minLength: 2)
                    Text(ComplicationFormat.time(entry.date, tz: second.timeZoneObject,
                                                 pref: entry.settings.hourPreference))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                    Text(ComplicationFormat.delta(from: homeTz, to: second.timeZoneObject,
                                                  at: entry.date))
                        .font(Brand.mono(9))
                        .opacity(0.7)
                }
            }
            if let ev = entry.nextEvent {
                Text("\(Brand.goldenHour) \(ComplicationFormat.shortName(ev.title, max: 14)) · \(ComplicationFormat.countdown(to: ev.startDate, from: entry.date))")
                    .font(Brand.mono(9))
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "timebase://upnext"))
    }
}

// MARK: - Inline
//
// Single-line slot, e.g. `Tokyo 23:15  +9h 30m`.

struct InlineComplication: View {
    let entry: TimebaseEntry

    var body: some View {
        let ordered = entry.orderedCities
        let home = entry.homeCity
        let homeTz = home?.timeZoneObject ?? .current
        // Prefer a non-home city to make the delta meaningful.
        let city = ordered.first { $0.id != home?.id } ?? home
        let tz = city?.timeZoneObject ?? .current
        let time = ComplicationFormat.time(entry.date, tz: tz,
                                           pref: entry.settings.hourPreference)
        let delta = ComplicationFormat.delta(from: homeTz, to: tz, at: entry.date)

        Text("\(ComplicationFormat.shortName(city?.name ?? "—", max: 10)) \(time)  \(delta)")
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "timebase://city/\(city?.id ?? "")"))
    }
}
