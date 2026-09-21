import Foundation
import SwiftUI

/// What the search screen opens on once you've used it (Andy, 2026-09-21).
///
/// The empty state taught the corpus in one sentence and then said the same
/// sentence forever, on a screen people reach repeatedly for the same
/// handful of teams. So search opens on what you last opened instead, and
/// the sentence is kept for the one run where it's still true.
///
/// **The result is remembered, not the query.** Typing "geor" and opening
/// Georgia hands back *Georgia* — one tap from the page — rather than four
/// letters and a second search.
///
/// **Only `(id, league)` is persisted.** The directory is already in memory,
/// so an entry resolves to the live `Team` at render time through
/// `TeamDirectoryStore`. Nothing here duplicates a model, no logo URL goes
/// stale in storage, and a change to `Team` needs no migration. An entry
/// that no longer resolves — a league whose directory hasn't loaded yet — is
/// skipped rather than drawn as an empty row.
@Observable
final class RecentSearchesStore {
    /// A result worth handing back. Games are deliberately absent: a game is
    /// the one result that expires, and the slate it came from is already
    /// the app's front page.
    nonisolated enum Entry: Codable, Hashable, Identifiable, Sendable {
        case team(id: String, league: League)
        case conference(ConferenceID)
        /// A snapshot, unlike the other two, and deliberately so: there is
        /// no athlete directory in memory to resolve an id against, and
        /// re-fetching ESPN's search on every render of the recents list
        /// would make opening an empty search box cost a request. The cost
        /// is that a traded player wears his old club here until he is
        /// opened again — which is the cheaper wrong answer than a row that
        /// can't draw itself (2026-09-21).
        case player(id: String, league: League, name: String,
                    teamName: String?, headshot: URL?)
        /// Stored as the id and the day, and resolved against the loaded
        /// slate — never a snapshot (Andy, 2026-09-21, asking for games
        /// here after they were left out). A game is the one result whose
        /// facts move: a stored score would be frozen the moment the game
        /// went live, and a frozen score is worse than no row. The cost is
        /// the other way round — a game whose day is no longer loaded
        /// cannot draw itself and is skipped for that render.
        case game(id: String, day: Date?)

        /// Stable across leagues, which is the whole point — the bare ESPN
        /// id collides between them, and this list always spans them
        /// (the 2026-09-06 Bills/Auburn collision, one list over).
        nonisolated var id: String {
            switch self {
            case let .team(id, league): "team.\(league.rawValue).\(id)"
            case let .conference(conference):
                "conf.\(conference.league.rawValue).\(conference.id)"
            case let .player(id, league, _, _, _):
                "player.\(league.rawValue).\(id)"
            case let .game(id, _): "game.\(id)"
            }
        }
    }

    /// Most-recent-first. Ten is a list you scan, not one you scroll: past
    /// that it stops being "where I just was" and starts being history,
    /// which is a different feature with a different screen.
    static let limit = 10

    private(set) var entries: [Entry] = []

    private static let key = "search.recents"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode([Entry].self, from: data)
        else { return }
        entries = Array(stored.prefix(Self.limit))
    }

    /// Two entries for the same thing are the same entry even when their
    /// snapshots differ — a player whose club changed must reorder, not
    /// appear twice.
    /// Moves an entry to the front, or adds it there. Re-opening something
    /// already in the list reorders rather than duplicating, so the list
    /// reads as recency and never as frequency.
    func record(_ entry: Entry) {
        var next = entries.filter { $0.id != entry.id }
        next.insert(entry, at: 0)
        entries = Array(next.prefix(Self.limit))
        persist()
    }

    /// Drops one entry — the dismiss affordance on its row (Andy,
    /// 2026-09-21). Keyed on `id` rather than equality so a player whose
    /// stored snapshot has drifted still matches the row you tapped.
    func remove(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

extension RecentSearchesStore.Entry {
    init(_ team: Team) { self = .team(id: team.id, league: team.league) }

    init(_ game: Game) { self = .game(id: game.id, day: game.date) }

    init(_ player: PlayerIdentity) {
        self = .player(id: player.athleteId, league: player.league,
                       name: player.name, teamName: player.teamName,
                       headshot: player.headshotURL)
    }
}
