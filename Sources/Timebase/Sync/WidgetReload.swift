import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Thin wrapper around WidgetKit so the host app can ask widgets to refresh
/// without importing WidgetKit at every call site. No-ops if WidgetKit isn't
/// available on the current target.
@MainActor
enum WidgetReload {
    static func requestAllTimelinesReload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
