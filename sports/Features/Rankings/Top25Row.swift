import SwiftUI

/// The poll's row in the Rankings list — the same shape as a conference
/// row, leading the list so the tab's #1 answer stays one obvious tap away.
struct Top25Row: View {
    /// The FBS polls, filtered and in picker order; pushed on to PollScreen.
    let polls: [Poll]
    /// Whose poll this is — the follow star's id, and the page's.
    var league: League = .collegeFootball
    /// Off on the Following card (Andy, 2026-09-25), which unfollows from
    /// its Edit mode instead — `ConferenceListRow`'s flag, for the same
    /// card.
    var showsFollow: Bool = true

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
            if showsFollow {
                PollFollowStar(league: league)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    /// The hub's one mark box, shared with `ConferenceListRow` and the
    /// league accordion's header.
    @ScaledMetric(relativeTo: .subheadline) private var markSize: CGFloat = 26

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            // A trophy, superseding the 2026-09-06 call for the league's
            // own mark (Andy, 2026-09-21). That row argued the mark says
            // *whose* top 25 — right while a second polling league was
            // hypothetical, and still the reason the accordion this sits
            // in is headed NCAAF. What changed is the company it keeps: on
            // a hub where every other row wears a real crest, a fifth
            // football among four was the one mark that identified nothing
            // its neighbours didn't. The trophy says what kind of table
            // this is, which is the question the row actually answers.
            //
            // The Leagues tab's own glyph, so the poll and the tab that
            // holds it agree.
            Image(systemName: "trophy.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: markSize, height: markSize)
            Text("Top 25")
                .font(.teamName)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: Spacing.sm)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The "#1 Ohio State" teaser came out 2026-09-21 with the leader lines
    /// on the conference rows and the table counts on the league headers —
    /// the hub answers "which table", and a standing answered a different
    /// question in the same row. The spoken label follows it out: VoiceOver
    /// should hear the row that is there, not the one that used to be.
    var accessibilitySummary: String { "Top 25" }
}
