import UIKit

@MainActor
enum AppIconManager {
    /// "AppIcon-FullDay" is a logical name for the primary icon. The actual
    /// asset is `AppIcon` (the catalog primary), and `setAlternateIconName`
    /// is called with `nil` to reset to it.
    static let primaryName = "AppIcon-FullDay"

    static let names  = ["AppIcon-FullDay", "AppIcon-Morning", "AppIcon-Midday", "AppIcon-GoldenHour", "AppIcon-Dusk"]
    static let labels = ["Full Day",        "Morning",         "Midday",         "Golden Hour",        "Dusk"]

    /// The actively-rendered icon name. iOS returns nil when the primary
    /// (FullDay in our setup) is active; we normalize that to "AppIcon-FullDay"
    /// for selection-state purposes.
    static var currentName: String {
        UIApplication.shared.alternateIconName ?? primaryName
    }

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    /// Sets the app icon. Passes nil for the primary (FullDay) so iOS treats
    /// it as "reset to primary". Always fires the system alert.
    static func setIcon(_ name: String) {
        guard supportsAlternateIcons else { return }
        guard name != currentName else { return }
        let target: String? = (name == primaryName) ? nil : name
        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                #if DEBUG
                print("Icon switch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
