import Foundation

/// Shared formatting helpers for the complication views.
enum ComplicationFormat {

    /// Fractional hour-of-day for a timezone at a date.
    static func fractionalHour(in tz: TimeZone, at date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    /// Wall-clock time for a city, honoring the synced 24-hour preference.
    static func time(_ date: Date, tz: TimeZone, pref: HourPreference) -> String {
        var fmt: Date.FormatStyle
        if pref.is24Hour == true {
            fmt = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        } else {
            fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .narrow)).minute(.twoDigits)
        }
        fmt.timeZone = tz
        return fmt.format(date)
    }

    /// Delta between two cities — `+9h`, `−2h 30m`.
    static func delta(from home: TimeZone, to other: TimeZone, at date: Date) -> String {
        let d = other.secondsFromGMT(for: date) - home.secondsFromGMT(for: date)
        if d == 0 { return "±0h" }
        let sign = d > 0 ? "+" : "−"
        let abs = Swift.abs(d)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        return m > 0 ? "\(sign)\(h)h \(m)m" : "\(sign)\(h)h"
    }

    /// Short city name — first word, capped, for tight slots.
    static func shortName(_ name: String, max: Int = 9) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return String(first.prefix(max))
    }

    /// Compact static countdown — `2h 14m`, `47m`, `now`.
    static func countdown(to target: Date, from now: Date) -> String {
        let interval = target.timeIntervalSince(now)
        if interval < 60 { return "now" }
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days >= 1 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours >= 1 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}
