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
    let destinations: [ConferenceDestination]

    /// The tables above this game, widest first: a pro league's
    /// whole-league one or the college-football division its teams play
    /// in, then the conference each side plays in. Empty where neither
    /// side can be placed — an unknown group gets no page, so the row
    /// doesn't render at all rather than wearing a dead badge.
    static func destinations(for game: Game) -> [ConferenceDestination] {
        var tables: [ConferenceDestination] = []
        if let league = leagueTable(for: game) {
            tables.append(league)
        }
        for team in [game.away.team, game.home.team] {
            guard let id = conference(of: team),
                  !tables.contains(where: { $0.conference == id }) else { continue }
            tables.append(named(id))
        }
        return tables
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

    private static func named(_ id: ConferenceID) -> ConferenceDestination {
        ConferenceDestination(conference: id, name: Conference.name(for: id))
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
                HStack(spacing: Spacing.sm) { badges }
                VStack(alignment: .leading, spacing: Spacing.xs) { badges }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var badges: some View {
        ForEach(destinations, id: \.self) { destination in
            NavigationLink(value: destination) {
                HeaderLinkBadge(title: destination.name)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(destination.name)
            .accessibilityHint("View standings")
        }
    }
}
