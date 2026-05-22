import SwiftUI

/// Light/dark/system appearance. Copied verbatim from iOS — its `Codable`
/// raw values must match so the `timebase.v1` blob decodes.
enum Appearance: String, Codable, CaseIterable {
    case system, light, dark

    var preferred: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 24-hour clock preference. Copied verbatim from iOS.
enum HourPreference: String, Codable, CaseIterable {
    case system, on, off

    /// Explicit `is24Hour`, or nil to follow the device locale.
    var is24Hour: Bool? {
        switch self {
        case .system: return nil
        case .on:     return true
        case .off:    return false
        }
    }
}

/// User settings persisted inside the `timebase.v1` blob.
///
/// iOS `UserSettings` carries iOS-only fields (`autoRotateIcon`,
/// `lastUserPickedIcon`, `shareStyle`). The Mac decodes leniently — all
/// fields optional — and ignores fields it doesn't use. When the Mac writes
/// the blob (scheduler later), it preserves unknown fields via
/// `CloudKVStore.writeCities`'s raw-JSON round-trip.
struct UserSettings: Codable {
    var hourPreference: HourPreference = .system
    var appearance: Appearance = .system

    enum CodingKeys: String, CodingKey {
        case hourPreference, appearance
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hourPreference = (try? c.decode(HourPreference.self, forKey: .hourPreference)) ?? .system
        self.appearance = (try? c.decode(Appearance.self, forKey: .appearance)) ?? .system
    }
}
