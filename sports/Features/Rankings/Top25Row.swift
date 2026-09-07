import SwiftUI

/// The poll's row in the Rankings list — the same shape as a conference
/// row, leading the list so the tab's #1 answer stays one obvious tap away.
struct Top25Row: View {
    /// The FBS polls, filtered and in picker order; pushed on to PollScreen.
    let polls: [Poll]
    /// Whose poll this is — the follow star's id, and the page's.
    var league: League = .collegeFootball

    var body: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink {
                PollScreen(polls: polls, league: league)
            } label: {
                rowContent
            }
            // Not `.plain`: this row is also a card the Following list
            // lifts and drags, and `.plain` fires on any touch-up still
            // inside the row — which a whole-card drag never leaves.
            .buttonStyle(SwipeSafeButtonStyle())
            .accessibilityIdentifier("rankings-top25-row")
            PollFollowStar(league: league)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            // The league's own mark, not a trophy (Andy, 2026-09-06): the
            // row is named "Top 25", which says nothing about *whose* top
            // 25 — fine while college football is the only league that
            // polls, and confusing the moment a second one does. Same
            // `ConferenceLogo` footprint as every other row's mark, so the
            // column still lines up.
            ConferenceLogo(url: league.logoURL)
            Text("Top 25")
                .font(.teamName)
                .foregroundStyle(.textPrimary)
            if let teaser {
                Text(teaser)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// "#1 Ohio State" from the first displayed poll (AP when present).
    /// The row doesn't track the picker choice — it's a teaser, not the poll.
    private var teaser: String? {
        guard let top = polls.first?.ranks.first else { return nil }
        return "#1 \(top.team.location)"
    }

    var accessibilitySummary: String {
        guard let top = polls.first?.ranks.first else { return "Top 25" }
        return "Top 25, number 1 \(top.team.location)"
    }
}
