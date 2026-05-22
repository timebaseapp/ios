import Foundation

/// Small shared clock helpers used across the watch views.
enum ClockMath {

    /// Fractional hour-of-day (0..<24) for a date in a given time zone.
    static func fractionalHour(in tz: TimeZone, date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    /// Wall-clock time string honoring the 24-hour preference.
    /// - `showMeridiem`: when false, the AM/PM marker is dropped — the world
    ///   clock relies on the time-of-day gradient for that context instead.
    ///   12-hour times then read cleanly as `4:16` (no leading zero);
    ///   24-hour times stay zero-padded as `04:16`.
    static func timeString(date: Date, tz: TimeZone, pref: HourPreference,
                           showMeridiem: Bool = true) -> String {
        let is24 = resolved24Hour(pref)

        if showMeridiem && !is24 {
            var fmt = Date.FormatStyle.dateTime
                .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            fmt.timeZone = tz
            return fmt.format(date)
        }

        // No meridiem (or 24-hour): compute directly for a clean, predictable
        // string the locale formatter won't pad unexpectedly.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        let h24 = c.hour ?? 0
        let minute = c.minute ?? 0
        if is24 {
            return String(format: "%02d:%02d", h24, minute)
        }
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d", h12, minute)
    }

    /// Resolves the effective 24-hour setting, consulting the device locale
    /// when the preference is `.system`.
    private static func resolved24Hour(_ pref: HourPreference) -> Bool {
        if let explicit = pref.is24Hour { return explicit }
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return !(fmt.dateFormat?.contains("a") ?? true)
    }

    /// Calendar-day offset of a city versus home (e.g. +1, -1, 0) — the same
    /// rule the iOS world-clock row uses for its `+1d` chip.
    static func dayOffset(cityTZ: TimeZone, homeTZ: TimeZone, date: Date) -> Int {
        var homeCal = Calendar(identifier: .gregorian); homeCal.timeZone = homeTZ
        var cityCal = Calendar(identifier: .gregorian); cityCal.timeZone = cityTZ
        let homeYMD = homeCal.dateComponents([.year, .month, .day], from: date)
        let cityYMD = cityCal.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let home = utc.date(from: homeYMD),
              let city = utc.date(from: cityYMD) else { return 0 }
        return Int((city.timeIntervalSince(home) / 86400).rounded())
    }

    /// Formats a fractional hour (e.g. 6.7) as a time label honoring the
    /// 24-hour preference — used for the sunrise / sunset captions.
    static func hourLabel(_ hour: Double, pref: HourPreference) -> String {
        let total = Int((hour * 60).rounded())
        let hh = (total / 60) % 24
        let mm = total % 60
        if pref.is24Hour == true {
            return String(format: "%02d:%02d", hh, mm)
        }
        let am = hh < 12
        let h12 = hh % 12 == 0 ? 12 : hh % 12
        return String(format: "%d:%02d %@", h12, mm, am ? "AM" : "PM")
    }
}
