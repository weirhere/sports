import SwiftUI
import WidgetKit

@main
struct StatSideWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextGameWidget()
        #if canImport(ActivityKit)
        GameLiveActivity()
        #endif
    }
}
