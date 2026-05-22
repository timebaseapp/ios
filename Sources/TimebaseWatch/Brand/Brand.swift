import SwiftUI

/// The Timebase brand vocabulary — type ramp, emoji, voice headlines.
///
/// Copied as *reference* from iOS, then re-tuned for the wrist. The anchors
/// (fonts, emoji, words) are identical to iOS by construction; only sizes
/// change because the watch renders smaller. The grain texture is
/// deliberately **omitted** on watchOS — fine tiled noise shimmers and crawls
/// under the low-refresh AOD compositor, the opposite of calm.
enum Brand {

    // MARK: - Type ramp

    /// Crimson Text — city names, headlines. Serif, warm.
    static func serif(_ size: CGFloat) -> Font {
        .custom("CrimsonText-SemiBold", size: size)
    }

    /// Departure Mono — deltas, countdowns, technical text. Monospaced.
    static func mono(_ size: CGFloat) -> Font {
        .custom("DepartureMono-Regular", size: size)
    }

    // MARK: - Emoji vocabulary
    //
    // Emoji are PART OF THE BRAND. They are never swapped for SF Symbols.
    // SF Symbols appear only for true UI affordances.

    static let home = "🏠"
    static let night = "🌙"
    static let earlyMorning = "☕"
    static let day = "☀"
    static let goldenHour = "🌇"

    /// The time-of-day emoji eyebrow for a city, chosen from its local hour.
    /// - 🌙 night, ☕ early morning, ☀ day, 🌇 golden hour.
    static func emoji(forHour hour: Double) -> String {
        switch hour {
        case 5..<8:   return earlyMorning
        case 8..<16:  return day
        case 16..<20: return goldenHour
        default:      return night
        }
    }

    // MARK: - Voice headlines

    /// Time-of-day greeting, mirroring the iOS easter-egg greetings.
    static func greeting(forHour hour: Int) -> String {
        switch hour {
        case 5..<11:  return "Good morning ☕"
        case 11..<14: return "What time is it in your favourite city?"
        case 14..<18: return "Golden hour, somewhere 🌇"
        case 18..<22: return "Don't schedule late, plan early"
        default:      return "Asleep somewhere, working somewhere 🌙"
        }
    }
}
