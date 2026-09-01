import Foundation

/// Ranked results for app-wide search. Pure and deterministic: same inputs,
/// same output, no clock, no network — the whole corpus is already loaded.
nonisolated struct SearchResults: Equatable {
    let teams: [Team]
    let conferences: [ConferenceTeams]
    let games: [Game]

    static let none = SearchResults(teams: [], conferences: [], games: [])

    var isEmpty: Bool {
        teams.isEmpty && conferences.isEmpty && games.isEmpty
    }

    static func compute(query: String,
                        conferences: [ConferenceTeams],
                        games: [Game],
                        followingIds: Set<String>) -> SearchResults {
        let folded = fold(query.trimmingCharacters(in: .whitespaces))
        guard !folded.isEmpty else { return .none }

        // The nil-id conference is the "Other" backstop bucket, not a
        // searchable destination.
        let matchedConferences = conferences
            .filter { $0.id != nil && fold($0.name).contains(folded) }
            .sorted { lhs, rhs in
                let (lp, rp) = (fold(lhs.name).hasPrefix(folded), fold(rhs.name).hasPrefix(folded))
                if lp != rp { return lp }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        let matchedGames = games.filter { game in
            matchTier(folded, team: game.home.team) != nil
                || matchTier(folded, team: game.away.team) != nil
                || [game.name, game.shortName].compactMap(\.self)
                    .contains { fold($0).contains(folded) }
        }

        return SearchResults(teams: rankedTeams(folded, in: conferences, followingIds: followingIds),
                             conferences: matchedConferences,
                             games: chronological(matchedGames))
    }

    /// The team-only slice, shared with the Teams and onboarding inline
    /// filters. Pass an empty follow set for a purely match-ranked list
    /// (onboarding does — rows toggle follows there, and a followed-first
    /// boost would reorder the list under the user's finger).
    static func teams(matching query: String,
                      in conferences: [ConferenceTeams],
                      followingIds: Set<String> = []) -> [Team] {
        let folded = fold(query.trimmingCharacters(in: .whitespaces))
        guard !folded.isEmpty else { return [] }
        return rankedTeams(folded, in: conferences, followingIds: followingIds)
    }

    // MARK: - Matching

    /// Case- and diacritic-insensitive: "jose" finds San José State.
    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Lower tier = better match. 0: exact abbreviation ("uga"), 1: a word
    /// in any field starts with the query, 2: substring anywhere.
    private static func matchTier(_ folded: String, team: Team) -> Int? {
        if let abbreviation = team.abbreviation, fold(abbreviation) == folded { return 0 }
        let fields = [team.location, team.name, team.abbreviation,
                      team.displayName, team.shortDisplayName]
            .compactMap(\.self).map(fold)
        if fields.contains(where: { $0.split(separator: " ").contains { $0.hasPrefix(folded) } }) {
            return 1
        }
        if fields.contains(where: { $0.contains(folded) }) { return 2 }
        return nil
    }

    private static func rankedTeams(_ folded: String,
                                    in conferences: [ConferenceTeams],
                                    followingIds: Set<String>) -> [Team] {
        var seen = Set<String>()
        return conferences.flatMap(\.teams)
            .compactMap { team -> (team: Team, followed: Bool, tier: Int, fcs: Bool)? in
                guard let tier = matchTier(folded, team: team),
                      seen.insert(team.id).inserted else { return nil }
                return (team, followingIds.contains(team.id), tier,
                        Conference.division(for: team.conferenceId) == .fcs)
            }
            .sorted { lhs, rhs in
                if lhs.followed != rhs.followed { return lhs.followed }
                if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                // The corpus doubled when FCS joined the directory; the
                // common query didn't. An equally-good FCS match sits
                // below the FBS one, under a followed team either way.
                if lhs.fcs != rhs.fcs { return rhs.fcs }
                return lhs.team.location.localizedCaseInsensitiveCompare(rhs.team.location) == .orderedAscending
            }
            .map(\.team)
    }

    /// Same ordering as the scoreboard's sections: dated games in kickoff
    /// order, undated last, ids as the stable tiebreak.
    private static func chronological(_ games: [Game]) -> [Game] {
        games.sorted {
            switch ($0.date, $1.date) {
            case let (a?, b?) where a != b: a < b
            case (nil, _?): false
            case (_?, nil): true
            default: $0.id < $1.id
            }
        }
    }
}
