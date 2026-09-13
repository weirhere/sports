import SwiftUI

/// The identity half of a table's caption row — "#" and "TEAM". Its own
/// view because a wide table pins it over the pinned identity column while
/// the numeric captions scroll with their numbers.
struct StandingsIdentityCaption: View {
    /// Fixed width for the pinned column; nil to fill the row.
    var width: CGFloat? = nil

    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16

    var body: some View {
        // The fixed frame only where there is one — `StandingsIdentityCell`
        // takes the same care, and for the same reason.
        if let width {
            content.frame(width: width, alignment: .leading)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.md) {
            Text("#")
                .frame(minWidth: positionWidth, alignment: .trailing)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The numeric half — one caption per column the league keeps, over the
/// numbers it promises.
struct StandingsNumbersCaption: View {
    let columns: [StandingsColumn]

    /// Scales the columns' own base widths with the text size, one metric
    /// for all of them so they stay in proportion.
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(columns) { column in
                Text(column.caption)
                    .frame(minWidth: column.width * scale, alignment: .trailing)
            }
        }
    }
}

/// The standings tables' column captions — # / TEAM, then whatever numeric
/// columns the league keeps — shared by the full tables (StandingsList) and
/// the game page's matchup slice so the two always read the same way.
///
/// Which columns those are is `League.standingsColumns`, because the
/// leagues disagree about what a standing is: college football shows a
/// conference record beside the overall, the NFL its whole ESPN-order
/// spread, the NBA win percentage and games back, the NHL games played,
/// its three-number record and the points it is actually ranked on.
///
/// This is the whole-row form. A table too wide for a phone splits the two
/// halves apart and pins the first — see `StandingsList`.
///
/// Visual-only: rows speak themselves as sentences, so VoiceOver skips it.
struct StandingsColumnCaptions: View {
    var league: League = .collegeFootball
    /// Overrides the league's own set, for the surfaces that show a
    /// narrower table than the league's page does.
    var columns: [StandingsColumn]? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            StandingsIdentityCaption()
            StandingsNumbersCaption(columns: columns ?? league.standingsColumns)
        }
        .standingsCaptionStyle()
        .padding(.horizontal, Spacing.lg)
    }
}

extension View {
    /// The caption row's own look, one definition for both layouts: meta
    /// gray, breathing room off the card header's hairline above, and a
    /// tighter gap to the first row below.
    func standingsCaptionStyle() -> some View {
        self
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .accessibilityHidden(true)
    }
}
