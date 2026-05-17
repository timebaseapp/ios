import UIKit

@MainActor
enum AppIconManager {
    static let names  = ["AppIcon-Morning", "AppIcon-Midday", "AppIcon-GoldenHour", "AppIcon-Dusk"]
    static let labels = ["Morning",         "Midday",         "Golden Hour",        "Dusk"]

    /// The actively-rendered icon name. iOS returns nil when the primary
    /// (AppIcon == Midday in our setup) is active; we normalize that to
    /// "AppIcon-Midday" for UI selection purposes.
    static var currentName: String {
        UIApplication.shared.alternateIconName ?? "AppIcon-Midday"
    }

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    /// Sets the app icon. Passes nil for the default (Midday) so iOS treats
    /// it as "reset to primary". Always fires the system alert.
    static func setIcon(_ name: String) {
        guard supportsAlternateIcons else { return }
        guard name != currentName else { return }
        let target: String? = (name == "AppIcon-Midday") ? nil : name
        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                #if DEBUG
                print("Icon switch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
