import Foundation
import CoreText

/// Registers the brand fonts (Crimson Text, Departure Mono) at app launch so
/// SwiftUI's `Font.custom("CrimsonText-SemiBold", size:)` resolves cleanly.
/// Mac apps don't honor iOS's `UIAppFonts` Info.plist key, so we register
/// the bundled font files programmatically.
enum FontRegistration {
    static func registerBrandFonts() {
        let entries: [(name: String, ext: String)] = [
            ("CrimsonText-SemiBold", "ttf"),
            ("DepartureMono-Regular", "otf"),
        ]
        for entry in entries {
            guard let url = Bundle.main.url(forResource: entry.name, withExtension: entry.ext) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            // Failure here is non-fatal — the views fall back to system font.
            _ = error
        }
    }
}
