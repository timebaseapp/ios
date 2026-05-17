import WidgetKit
import SwiftUI
import AppIntents

/// Control Center tile (iOS 18+) — shows home city's current time. Tap
/// opens Timebase to the world clock.
@available(iOSApplicationExtension 18.0, *)
struct TimebaseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "TimebaseHomeControl") {
            ControlWidgetButton(action: OpenTimebaseIntent()) {
                let p = WidgetStore.load() ?? WidgetStore.placeholder
                let home = p.cities.first(where: { $0.id == p.homeCityId })
                        ?? p.cities.first
                Label {
                    Text(home?.name ?? "Timebase")
                } icon: {
                    Image(systemName: "clock")
                }
            }
        }
        .displayName("Home time")
        .description("Tap to open Timebase.")
    }
}

/// Lightweight intent that just opens the app. Control Center buttons
/// require a `PerformIntent` so they have something to fire.
struct OpenTimebaseIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Timebase"
    static let openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}
