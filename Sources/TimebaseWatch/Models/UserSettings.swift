import SwiftUI

/// Light/dark/system appearance. Copied verbatim from iOS — its `Codable`
/// raw values must match so the `timebase.v1` blob decodes.
enum Appearance: String, Codable, CaseIterable {
    case system, light, dark

    var preferred: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 24-hour clock preference. Copied verbatim from iOS.
enum HourPreference: String, Codable, CaseIterable {
    case system, on, off

    /// Returns explicit `is24Hour` or nil to follow the device locale.
    var is24Hour: Bool? {
        switch self {
        case .system: return nil
        case .on: return true
        case .off: return false
        }
    }
}

/// User settings persisted inside the `timebase.v1` blob.
///
/// The iOS `UserSettings` also carries `autoRotateIcon` and
/// `lastUserPickedIcon`. Those keys are decoded leniently (all-optional /
/// defaulted) and simply ignored on the Watch — an auto-rotating app icon is
/// not a watchOS concept. Re-encoding is never done by the Watch (read-only),
/// so dropping them does not corrupt the iPhone's blob.
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
