import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

/// One followed game, live on the lock screen and in the Dynamic Island.
///
/// The three containers are one design at three sizes, not three designs:
/// the expanded island is the lock-screen card on the system's black
/// ground, and compact is a strict subset of it. Minimal is deliberately
/// not designed — it only appears when a second activity outranks ours, and
/// none of the four apps studied draw anything meaningful there.
struct GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            GameActivityCard(attributes: context.attributes,
                             state: context.state,
                             isStale: context.isStale)
                .activityBackgroundTint(Color.bgCard)
                .activitySystemActionForegroundColor(Color.textPrimary)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                // The whole card, full width. Leading and trailing stay
                // empty on purpose: splitting the chassis across the
                // sensor housing would break the symmetry the layout is.
                DynamicIslandExpandedRegion(.bottom) {
                    GameActivityCard(attributes: context.attributes,
                                     state: context.state,
                                     isStale: context.isStale)
                }
            } compactLeading: {
                ActivityCompactSide(side: context.attributes.away,
                                    score: context.state.awayScore,
                                    showsScore: context.state.showsScores,
                                    mirrored: false)
            } compactTrailing: {
                ActivityCompactSide(side: context.attributes.home,
                                    score: context.state.homeScore,
                                    showsScore: context.state.showsScores,
                                    mirrored: true)
            } minimal: {
                ActivityCompactSide(side: context.attributes.home,
                                    score: context.state.homeScore,
                                    showsScore: false,
                                    mirrored: false)
            }
            .keylineTint(context.state.phase.isLive && !context.isStale ? .liveAccent : nil)
            .widgetURL(context.attributes.deepLink)
        }
    }
}
#endif
