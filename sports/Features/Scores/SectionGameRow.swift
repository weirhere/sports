import SwiftUI

/// One game in a Scores section: the row, its push, and its follow/share
/// menu.
///
/// Its own view, lifted out of `SectionAccordion` (2026-09-24), so each row
/// diffs on its own game. Inside the accordion's `ForEach` every row rebuilt
/// its context menu, share card and share text — twice over, the card and
/// the message each composing the sentence — and asked `FollowingStore`
/// four times, whenever any part of the section changed.
///
/// Spoiler mode (E30, 2026-10-19) lands here too: a concealed row's status
/// column reveals the score in place, the menu offers the same reveal
/// instead of Share (a share is the score), and VoiceOver gets the reveal
/// as a custom action, since the row is one element and swallows the
/// button inside it. The push carries the real game: the detail page
/// conceals itself.
struct SectionGameRow: View {
    let game: Game
    let leagueTag: League?
    /// The conference this row's section is, for tagging a visitor.
    var sectionConference: ConferenceID? = nil

    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(SpoilerStore.self) private var spoiler
    @Environment(\.spoilerGuard) private var spoilerGuard

    var body: some View {
        let awayTitle = followActionTitle(for: game.away.team)
        let homeTitle = followActionTitle(for: game.home.team)
        let concealed = spoilerGuard.conceals(game)
        NavigationLink(value: game) {
            GameRow(game: game, timeOnly: true, leagueTag: leagueTag,
                    showsLine: uiState.showsLines, sectionConference: sectionConference,
                    onReveal: concealed ? { spoiler.reveal(game) } : nil)
        }
        // Not `.plain`: a full-width row is wider than any swipe, so the
        // day swipe used to end on this link.
        .buttonStyle(SwipeSafeButtonStyle())
        .contextMenu {
            followMenuButton(for: game.away.team, title: awayTitle)
            followMenuButton(for: game.home.team, title: homeTitle)
            if concealed {
                Button {
                    spoiler.reveal(game)
                } label: {
                    Label("Reveal score", systemImage: "eye")
                }
            } else {
                let shareText = game.shareText
                ShareLink(
                    item: GameShareCard(game: game, summary: nil, shareText: shareText),
                    message: Text(shareText),
                    preview: SharePreview(game.shortName ?? game.name ?? "Game")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        // The row collapses to one VO element, which swallows the menu —
        // custom actions restore parity.
        .accessibilityAction(named: awayTitle) { following.toggle(game.away.team) }
        .accessibilityAction(named: homeTitle) { following.toggle(game.home.team) }
        .accessibilityActions {
            if concealed {
                Button("Reveal score") { spoiler.reveal(game) }
            }
        }
    }

    private func followMenuButton(for team: Team, title: String) -> some View {
        Button {
            following.toggle(team)
        } label: {
            Label(title, systemImage: following.isFollowing(team) ? "star.slash" : "star")
        }
    }

    private func followActionTitle(for team: Team) -> String {
        following.isFollowing(team) ? "Unfollow \(team.location)" : "Follow \(team.location)"
    }
}
