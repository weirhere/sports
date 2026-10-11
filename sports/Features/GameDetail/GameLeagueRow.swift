import SwiftUI

/// What this game belongs to, as one row of the Game info card: the
/// league's mark in the icon gutter the kickoff, network and weather
/// lines use, then a tappable `HeaderLinkBadge` per table it counts
/// toward — the league, then each side's conference.
///
/// The mark stands in for a "League" label (Andy, 2026-09-09) — the
/// shield says which competition faster than the word does, and it puts
/// the row on the same x as every line beneath it. VoiceOver still hears
/// the words, since a mark reads as nothing at all.
///
/// A conference game contributes one conference badge, not two: the
/// badges are the tables this game appears in, and both sides share one.
struct GameLeagueRow: View {
    let league: League
    let badges: [Badge]

    /// One badge: what it says, and the page it opens. The two differ for
    /// a pro side — the badge names the team's division, the page is the
    /// conference above it — so they're carried separately rather than
    /// letting the label stand in as the page's title.
    struct Badge: Hashable {
        let title: String
        let destination: ConferenceDestination
    }

    /// The tables above this game, widest first: a pro league's
    /// whole-league one or the college-football division its teams play
    /// in, then the group each side plays in. Empty where neither side can
    /// be placed — an unknown group gets no page, so the row doesn't
    /// render at all rather than wearing a dead badge.
    static func badges(for game: Game) -> [Badge] {
        var badges: [Badge] = []
        if let league = leagueTable(for: game) {
            badges.append(Badge(title: league.name, destination: league))
        }
        for team in [game.away.team, game.home.team] {
            guard let id = conference(of: team) else { continue }
            let title = groupName(of: team) ?? Conference.name(for: id)
            // Deduped on the *label*, not the conference: two AFC teams
            // from different divisions are two badges, where one
            // conference was one badge. A divisional game still collapses
            // to one, which is the rule this row already had.
            guard !badges.contains(where: { $0.title == title }) else { continue }
            badges.append(Badge(title: title, destination: named(id, anchoring: team)))
        }
        return badges
    }

    private static func leagueTable(for game: Game) -> ConferenceDestination? {
        let league = game.home.team.league
        if let wide = Conference.leagueWideId(in: league) {
            return named(ConferenceID(league, wide))
        }
        for team in [game.home.team, game.away.team] {
            guard let own = team.conference else { continue }
            if Conference.isDivisionRoot(own.id, in: league) { return named(own) }
            if let root = Conference.root(above: own) { return named(root) }
        }
        return nil
    }

    /// The conference rung a team plays in: college football's own group
    /// id, or the conference above the division a pro league files it in.
    ///
    /// The division fold is the whole trick. A pro scoreboard ships no
    /// group at all, so the mapper stamps a team with its *division* from
    /// the registry — which is why the id in hand is as likely to be
    /// "AFC East" as "AFC", and why it gets walked up either way.
    private static func conference(of team: Team) -> ConferenceID? {
        let league = team.league
        guard let id = team.conference.map(\.id)
                ?? Conference.division(forTeamId: team.id, in: league) else { return nil }
        guard !Conference.isDivisionRoot(id, in: league) else { return nil }
        let conference = Conference.parent(of: id, in: league) ?? id
        return Conference.isKnown(conference, in: league) ? ConferenceID(league, conference) : nil
    }

    /// The finest group a team actually plays in — "AFC East", not "AFC"
    /// (Andy, 2026-09-21). A pro scoreboard ships no group, so the mapper
    /// stamps the team with its division from the registry; this reads that
    /// rather than walking up to its parent the way the destination does.
    private static func groupName(of team: Team) -> String? {
        let league = team.league
        guard let id = team.conference.map(\.id)
                ?? Conference.division(forTeamId: team.id, in: league),
              !Conference.isDivisionRoot(id, in: league),
              Conference.isKnown(id, in: league) else { return nil }
        let name = Conference.name(for: ConferenceID(league, id))
        return name == "Other" ? nil : name
    }

    private static func named(_ id: ConferenceID) -> ConferenceDestination {
        ConferenceDestination(conference: id, name: Conference.name(for: id))
    }

    /// The badge says the division and the link goes to the conference,
    /// because a division has no page of its own (2026-09-26) — the AFC's
    /// page stacks its four. The page is titled by what it *is* ("AFC"),
    /// and anchors on this side's row so it lands on the division the
    /// badge named: TeamPage's group badge, same rule. Titling it by the
    /// badge put "AFC West" over all four AFC divisions (Andy, 2026-10-11).
    private static func named(_ id: ConferenceID, anchoring team: Team) -> ConferenceDestination {
        ConferenceDestination(conference: id, name: Conference.name(for: id),
                              highlightTeamId: team.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ConferenceLogo(url: league.logoURL, league: league)
                .frame(width: 20)
                .accessibilityHidden(true)
            // Two long conference names and a division root don't fit one
            // line at every text size, so the badges wrap rather than
            // truncating a name the badge exists to say.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { badgeLinks }
                VStack(alignment: .leading, spacing: Spacing.xs) { badgeLinks }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var badgeLinks: some View {
        ForEach(badges, id: \.self) { badge in
            NavigationLink(value: badge.destination) {
                HeaderLinkBadge(title: badge.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(badge.title)
            .accessibilityHint("View standings")
        }
    }
}
