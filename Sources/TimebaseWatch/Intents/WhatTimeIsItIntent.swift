import Foundation
import AppIntents

/// "What time is it in [city]?" — re-implemented for Siri on the Watch.
///
/// Self-contained: takes a `CityEntity`, formats a time string, returns
/// `ReturnsValue<String> & ProvidesDialog`. Works on the Watch via Siri with
/// no additional plumbing.
struct WhatTimeIsItIntent: AppIntent {
    static let title: LocalizedStringResource = "What time is it"
    static let description = IntentDescription(
        "Get the current time in a city.",
        categoryName: "Time"
    )

    @Parameter(title: "City")
    var city: CityEntity

    static var parameterSummary: some ParameterSummary {
        Summary("What time is it in \(\.$city)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let tz = TimeZone(identifier: city.timezone) ?? .current
        var fmt = Date.FormatStyle.dateTime
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute(.twoDigits)
            .weekday(.abbreviated)
        fmt.timeZone = tz
        let time = fmt.format(.now)
        let phrase = "It's \(time) in \(city.name)."
        return .result(value: phrase, dialog: IntentDialog(stringLiteral: phrase))
    }
}

/// Surfaces the intent to Siri / Shortcuts on the Watch.
struct TimebaseWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatTimeIsItIntent(),
            phrases: [
                "What time is it in \(.applicationName)",
                "Ask \(.applicationName) the time"
            ],
            shortTitle: "What time is it",
            systemImageName: "clock"
        )
    }
}
