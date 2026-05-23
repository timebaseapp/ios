import Foundation

/// Countdown formatting — `5d 10h 22m 35s`, drops leading zero-units so very
/// short countdowns read as `42s`, hours-away as `3h 17m 04s`, etc. Built
/// for `TimelineView(.periodic)` to recompute once per second.
enum Countdown {
    static func format(to target: Date, from now: Date) -> String {
        let secs = max(0, Int(target.timeIntervalSince(now).rounded()))
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60
        let s = secs % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if days > 0 || hours > 0 { parts.append("\(hours)h") }
        if days > 0 || hours > 0 || mins > 0 { parts.append("\(mins)m") }
        parts.append("\(s)s")
        return parts.joined(separator: " ")
    }
}
