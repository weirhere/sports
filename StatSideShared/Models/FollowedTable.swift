import Foundation

/// One followable table — a poll or a conference/league group.
///
/// The two follow sets (`FollowingStore.pollLeagues` and
/// `.conferenceIds`) answer the same question in two shapes: "which
/// standings-shaped thing do I care about". The tables hub already lists
/// them together under Following, and since 2026-09-06 the Scores screen
/// hoists them together too — so they need one identity, one token, and
/// one order.
///
/// Deliberately *not* a team follow. A team follow puts games in the
/// Scores Following section; a table follow moves that table's section up
/// the page instead (Andy, 2026-09-06). Following is "my teams"; a
/// conference is a slate, and a slate the size of the Big Ten would bury
/// the three games you actually care about.
nonisolated enum FollowedTable: Hashable, Sendable, Identifiable {
    /// A league's poll — college football's Top 25 is the only one today.
    case poll(League)
    /// A conference, an NFL division, or a whole league standing as one
    /// table (the NFL's group 9).
    case conference(ConferenceID)

    /// The persistence + drag token: `"poll-cfb"` / `"conf-cfb-8"`.
    var token: String {
        switch self {
        case .poll(let league): "poll-\(league.rawValue)"
        case .conference(let id): "conf-\(id.token)"
        }
    }

    var id: String { token }

    init?(token: String) {
        if token.hasPrefix("poll-"),
           let league = League(rawValue: String(token.dropFirst("poll-".count))) {
            self = .poll(league)
        } else if token.hasPrefix("conf-"),
                  let id = ConferenceID(token: String(token.dropFirst("conf-".count))) {
            self = .conference(id)
        } else {
            return nil
        }
    }

    var league: League {
        switch self {
        case .poll(let league): league
        case .conference(let id): id.league
        }
    }

    /// What the Scores section header calls it.
    var name: String {
        switch self {
        case .poll: "Top 25"
        case .conference(let id): Conference.name(for: id)
        }
    }

    /// The mark beside that header. A poll has none — the Scores header
    /// and the tables hub row both wear a trophy glyph instead.
    var logoURL: URL? {
        switch self {
        case .poll: nil
        case .conference(let id): Conference.logoURL(for: id)
        }
    }

    /// Whether this table claims a game.
    ///
    /// The conference case walks the group chain, so a followed AFC
    /// matches a Bills game even though ESPN's NFL scoreboard only ever
    /// hands us the *division* id — and a followed NFL (group 9) matches
    /// all 32 teams.
    func matches(_ game: Game) -> Bool {
        switch self {
        case .poll(let league):
            game.home.team.league == league && game.involvesRankedTeam
        case .conference(let id):
            claims(game.home.team, id) || claims(game.away.team, id)
        }
    }

    private func claims(_ team: Team, _ id: ConferenceID) -> Bool {
        guard let conference = team.conference else { return false }
        return Conference.chain(for: conference).contains(id)
    }

    /// The order a followed set falls into before anyone drags anything:
    /// polls first (a league's headline answer), then its groups widest
    /// first, alphabetically inside a tier — the tables hub's own order.
    static func defaultOrder(_ lhs: FollowedTable, _ rhs: FollowedTable) -> Bool {
        guard lhs.league == rhs.league else {
            return (League.allCases.firstIndex(of: lhs.league) ?? 0)
                < (League.allCases.firstIndex(of: rhs.league) ?? 0)
        }
        switch (lhs, rhs) {
        case (.poll, .poll): return false
        case (.poll, .conference): return true
        case (.conference, .poll): return false
        case let (.conference(a), .conference(b)):
            let (ta, tb) = (Conference.tier(for: a.id, in: a.league),
                            Conference.tier(for: b.id, in: b.league))
            return ta == tb
                ? Conference.name(for: a) < Conference.name(for: b)
                : ta < tb
        }
    }
}
