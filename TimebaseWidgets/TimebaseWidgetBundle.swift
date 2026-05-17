import WidgetKit
import SwiftUI

@main
struct TimebaseWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorldClockWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            EventCountdownLiveActivity()
        }
    }
}
