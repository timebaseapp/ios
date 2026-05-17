import Foundation
import AppIntents

/// "What time is it in [city]?" — returns a spoken/displayed time string.
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
