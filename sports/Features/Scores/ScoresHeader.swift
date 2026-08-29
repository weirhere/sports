import SwiftUI

/// The chrome row above the week strip: StatSide wordmark left; the live
/// filter and view-options funnel right. Grouping and season moved into
/// `ScoreFilterSheet` (2026-08-29) when four chips outgrew the row — the
/// funnel chip carries any non-default state. The live chip is permanent
/// (Andy, same day): a stable home beats appearing mid-Saturday, and an
/// empty live week explains itself instead of hiding the toggle.
struct ScoresHeader: View {
    let liveOnly: Bool
    let scoreFilter: ScoreFilter?
    /// The selected season when browsing the past, nil on the current one.
    let pastSeasonYear: Int?
    let onToggleLive: () -> Void
    let onTapFilter: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            wordmark
            Spacer(minLength: 0)
            // One grouped capsule for both controls — FotMob's tap-target
            // language (Andy, 2026-08-29): the Live pill leads, the funnel
            // rides where FotMob keeps its calendar. Segments paint their
            // own fill only when active; the group carries the chrome.
            HStack(spacing: 2) {
                LiveFilterChip(liveOnly: liveOnly, onToggle: onToggleLive)
                ScoreFilterChip(filter: scoreFilter, pastSeasonYear: pastSeasonYear,
                                onTap: onTapFilter)
            }
            .padding(4)
            .glassCapsule(fallback: Color.bgElevated)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var wordmark: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "football.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("StatSide")
                .font(.system(size: 17, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ScoresHeader(liveOnly: false, scoreFilter: nil,
                     pastSeasonYear: nil, onToggleLive: {}, onTapFilter: {})
        ScoresHeader(liveOnly: true, scoreFilter: .conference(8),
                     pastSeasonYear: nil, onToggleLive: {}, onTapFilter: {})
        ScoresHeader(liveOnly: false, scoreFilter: .conference(12),
                     pastSeasonYear: 2019, onToggleLive: {}, onTapFilter: {})
    }
    .background(Color.bgPrimary)
}
