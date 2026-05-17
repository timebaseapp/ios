import Foundation
import AppIntents

/// "Plan a meeting" — opens Timebase. The optional city parameter is
/// stashed in the App Group so the host app can read it on next launch and
/// pre-seed the scheduler.
struct PlanMeetingIntent: AppIntent {
    static let title: LocalizedStringResource = "Plan a meeting"
    static let description = IntentDescription(
        "Open Timebase's meeting scheduler.",
        categoryName: "Scheduling"
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "With city")
    var city: CityEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Plan a meeting with \(\.$city)")
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.cc.timebase.ios")
        if let city {
            defaults?.set(city.id, forKey: "timebase.pendingSchedulerCityId")
        }
        defaults?.set(true, forKey: "timebase.pendingShowScheduler")
        return .result()
    }
}
