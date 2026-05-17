import AppIntents

/// Registers Timebase intents with Shortcuts, Spotlight, and Siri. Phrases
/// must include `\(.applicationName)` so they appear as donated shortcuts.
struct TimebaseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatTimeIsItIntent(),
            phrases: [
                "What time is it in \(.applicationName)",
                "Time in \(.applicationName)",
                "Check the time in \(.applicationName)"
            ],
            shortTitle: "What time is it",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: PlanMeetingIntent(),
            phrases: [
                "Plan a meeting in \(.applicationName)",
                "Schedule a meeting in \(.applicationName)"
            ],
            shortTitle: "Plan a meeting",
            systemImageName: "calendar.badge.plus"
        )
    }
}
