import SwiftUI

/// The standings tables' column captions — # / TEAM, then whatever numeric
/// columns the league keeps — shared by the full tables (StandingsList) and
/// the game page's matchup slice so the two always read the same way.
///
/// Which columns those are is `League.standingsColumns`, because the
/// leagues disagree about what a standing is: football shows a conference
/// record beside the overall, the NBA win percentage and games back, the
/// NHL games played, its three-number record and the points it is actually
/// ranked on.
///
/// Visual-only: rows speak themselves as sentences, so VoiceOver skips it.
struct StandingsColumnCaptions: View {
    var league: League = .collegeFootball
    // Mirror ConferenceStandingRow's column metrics so captions align
    // with the numbers beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16
    /// Scales the columns' own base widths with the text size, one metric
    /// for all of them so they stay in proportion.
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text("#")
                .frame(minWidth: positionWidth, alignment: .trailing)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(league.standingsColumns) { column in
                Text(column.caption)
                    .frame(minWidth: column.width * scale, alignment: .trailing)
            }
        }
        .font(.meta)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Spacing.lg)
        // Breathing room off the card header's hairline above.
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .accessibilityHidden(true)
    }
}
