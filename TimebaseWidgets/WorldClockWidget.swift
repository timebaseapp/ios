import WidgetKit
import SwiftUI

// MARK: - Widget

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimebaseWorldClock", provider: WorldClockProvider()) { entry in
            WorldClockEntryView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("Your Timebase cities at a glance.")
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

struct WorldClockEntry: TimelineEntry {
    let date: Date
    let persisted: WidgetPersisted
}

struct WorldClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorldClockEntry {
        WorldClockEntry(date: .now, persisted: WidgetStore.placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (WorldClockEntry) -> Void) {
        completion(WorldClockEntry(
            date: .now,
            persisted: WidgetStore.load() ?? WidgetStore.placeholder
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorldClockEntry>) -> Void) {
        let p = WidgetStore.load() ?? WidgetStore.placeholder
        // Produce one entry per minute for the next 60 minutes so the
        // widget refreshes without WidgetCenter reloads.
        var entries: [WorldClockEntry] = []
        let cal = Calendar.current
        let baseDate = cal.date(bySetting: .second, value: 0, of: .now) ?? .now
        for i in 0 ..< 60 {
            if let d = cal.date(byAdding: .minute, value: i, to: baseDate) {
                entries.append(WorldClockEntry(date: d, persisted: p))
            }
        }
        let next = cal.date(byAdding: .minute, value: 60, to: baseDate) ?? .now
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - Entry view

struct WorldClockEntryView: View {
    let entry: WorldClockEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:        SmallView(entry: entry)
        case .systemMedium:       MediumView(entry: entry)
        case .systemLarge:        LargeView(entry: entry)
        case .accessoryCircular:  AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectView(entry: entry)
        case .accessoryInline:    AccessoryInlineView(entry: entry)
        default:                  SmallView(entry: entry)
        }
    }
}

// MARK: - System widgets

private struct SmallView: View {
    let entry: WorldClockEntry

    var body: some View {
        let city = entry.persisted.cities.first(where: { $0.id == entry.persisted.homeCityId })
                ?? entry.persisted.cities.first
        let h = fractionalHour(in: city?.timeZone ?? .current, at: entry.date)
        let grad = WidgetTimeColor.gradient(forHour: h)
        let fg = WidgetTimeColor.foreground(forHour: h)

        // Empty body + the gradient + text both go in containerBackground so
        // the color bleeds to the rounded corners.
        Color.clear
            .containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(city?.name ?? "—")
                            .font(.system(size: 13))
                        Spacer()
                        Text(timeString(date: entry.date, tz: city?.timeZone ?? .current))
                            .font(.system(size: 28, weight: .heavy))
                            .monospacedDigit()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .foregroundStyle(fg)
                }
            }
            .widgetURL(URL(string: "timebase://city/\(city?.id ?? "")"))
    }
}

private struct MediumView: View {
    let entry: WorldClockEntry

    var body: some View {
        let cities = orderedCities(persisted: entry.persisted).prefix(3)
        Color.clear
            .containerBackground(for: .widget) {
                VStack(spacing: 0) {
                    ForEach(Array(cities), id: \.id) { city in
                        row(for: city)
                    }
                }
            }
            .widgetURL(URL(string: "timebase://"))
    }

    private func row(for city: WidgetCity) -> some View {
        let h = fractionalHour(in: city.timeZone, at: entry.date)
        let grad = WidgetTimeColor.gradient(forHour: h)
        let fg = WidgetTimeColor.foreground(forHour: h)
        return ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            HStack {
                Text(city.name)
                    .font(.system(size: 14))
                Spacer()
                Text(timeString(date: entry.date, tz: city.timeZone))
                    .font(.system(size: 18, weight: .heavy))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .foregroundStyle(fg)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct LargeView: View {
    let entry: WorldClockEntry

    var body: some View {
        let cities = orderedCities(persisted: entry.persisted).prefix(5)
        Color.clear
            .containerBackground(for: .widget) {
                VStack(spacing: 0) {
                    ForEach(Array(cities), id: \.id) { city in
                        row(for: city)
                    }
                }
            }
            .widgetURL(URL(string: "timebase://"))
    }

    private func row(for city: WidgetCity) -> some View {
        let h = fractionalHour(in: city.timeZone, at: entry.date)
        let grad = WidgetTimeColor.gradient(forHour: h)
        let fg = WidgetTimeColor.foreground(forHour: h)
        return ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            HStack {
                Text(city.name)
                    .font(.system(size: 15))
                Spacer()
                Text(timeString(date: entry.date, tz: city.timeZone))
                    .font(.system(size: 19, weight: .heavy))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .foregroundStyle(fg)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Lock screen widgets

private struct AccessoryCircularView: View {
    let entry: WorldClockEntry

    var body: some View {
        let city = entry.persisted.cities.first(where: { $0.id == entry.persisted.homeCityId })
                ?? entry.persisted.cities.first
        Gauge(value: 0) {
            Text(short(city?.name ?? "—"))
        } currentValueLabel: {
            Text(shortTime(date: entry.date, tz: city?.timeZone ?? .current))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "timebase://"))
    }

    private func short(_ s: String) -> String {
        let trimmed = s.split(separator: " ").first.map(String.init) ?? s
        return String(trimmed.prefix(4))
    }
}

private struct AccessoryRectView: View {
    let entry: WorldClockEntry

    var body: some View {
        let cities = orderedCities(persisted: entry.persisted).prefix(2)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(cities), id: \.id) { city in
                HStack {
                    Text(city.name)
                        .font(.system(size: 13))
                    Spacer()
                    Text(timeString(date: entry.date, tz: city.timeZone))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "timebase://"))
    }
}

private struct AccessoryInlineView: View {
    let entry: WorldClockEntry

    var body: some View {
        let cities = orderedCities(persisted: entry.persisted).prefix(3)
        let parts = cities.map { city in
            "\(short(city.name)) \(shortTime(date: entry.date, tz: city.timeZone))"
        }
        Text(parts.joined(separator: " · "))
            .containerBackground(for: .widget) { Color.clear }
    }

    private func short(_ s: String) -> String {
        s.split(separator: " ").first.map(String.init) ?? s
    }
}

// MARK: - Helpers

private func orderedCities(persisted: WidgetPersisted) -> [WidgetCity] {
    persisted.cities.sorted { a, b in
        let aOff = a.timeZone.secondsFromGMT()
        let bOff = b.timeZone.secondsFromGMT()
        if aOff == bOff { return a.name < b.name }
        return aOff < bOff
    }
}

private func fractionalHour(in tz: TimeZone, at date: Date) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.hour, .minute], from: date)
    return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
}

private func timeString(date: Date, tz: TimeZone) -> String {
    var fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
    fmt.timeZone = tz
    return fmt.format(date)
}

private func shortTime(date: Date, tz: TimeZone) -> String {
    var fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .narrow)).minute(.twoDigits)
    fmt.timeZone = tz
    return fmt.format(date)
}
