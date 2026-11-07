import Foundation
import SwiftUI

/// The athlete half of search, which is the half that costs a request.
///
/// Every other corpus the search box reads is already in memory, so results
/// land on the keystroke. Athletes come from ESPN's search endpoint, and a
/// request per keystroke would be both slow and rude — the API rules say be
/// a polite guest. So this debounces, and it cancels: a query that has been
/// superseded stops rather than racing the one after it back.
///
/// Athletes arrive **beside** the instant results, never instead of them. A
/// team match still renders on the keystroke that produced it; the Players
/// section fills in a beat later. Making the whole screen wait on the
/// network would trade the thing search is good at for the thing it just
/// gained.
@Observable
@MainActor
final class AthleteSearchStore {
    private(set) var athletes: [PlayerIdentity] = []
    /// The stories the same request found, for the News scope (E26). Held
    /// here because they ride the athletes' response: one request, two
    /// kinds of result.
    private(set) var stories: [NewsStory] = []
    /// True only while a request for the *current* query is outstanding, so
    /// a spinner can't outlive the query that asked for it.
    private(set) var isSearching = false

    /// Long enough that typing a name doesn't fire per letter, short enough
    /// that the section is there by the time the eye reaches it.
    private static let debounce = Duration.milliseconds(300)
    /// ESPN indexes every sport; asking for more than the page shows only
    /// buys more of the ones we filter out.
    private static let limit = 10

    private let client: AthleteSearchClient
    private var task: Task<Void, Never>?
    private var query = ""

    init(client: AthleteSearchClient = AthleteSearchClient()) {
        self.client = client
    }

    /// Call on every query change. Cheap when nothing changed.
    ///
    /// `collegeTeamsInScope` is, per college league, the display names of
    /// every team the app has a page for. ESPN's college slugs are wider
    /// than that: `college-football` indexes Division II and III too, so a
    /// "McDavid" query returns Mars Hill Lions beside Harvard Crimson, and
    /// `mens-college-basketball` returns Chadron State, a Division II school
    /// (2026-11-06). Harvard is a real FCS page here; Mars Hill and Chadron
    /// State are nothing, and a row that opens nothing is worse than no row.
    /// Verified 2026-09-21 for football against both standings groups, and
    /// 2026-11-06 for basketball: the men's directory has 365 schools and the
    /// women's 363, Wofford and Arkansas State among them, Chadron State in
    /// neither.
    ///
    /// The directory is the arbiter rather than a hardcoded division list,
    /// so the day the app adds a division the filter follows it for free.
    func search(_ text: String, collegeTeamsInScope: [League: Set<String>]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        task?.cancel()

        guard !trimmed.isEmpty else {
            // A cleared field costs no request and keeps no stale people.
            athletes = []
            stories = []
            isSearching = false
            return
        }

        isSearching = true
        task = Task { [weak self, client] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            // Typed: a bare `([], [])` fallback infers an unlabeled tuple.
            let found: (athletes: [PlayerIdentity], stories: [NewsStory]) =
                (try? await client.search(matching: trimmed, limit: Self.limit)) ?? ([], [])
            guard !Task.isCancelled else { return }
            guard let self, self.query == trimmed else { return }
            self.stories = found.stories
            self.athletes = Self.inScope(found.athletes, collegeTeams: collegeTeamsInScope)
            self.isSearching = false
        }
    }

    /// The athletes worth a row: one per person, and, in a college league,
    /// only those whose school has a page.
    ///
    /// One per person is keyed on league, name and team, not the athlete id.
    /// ESPN keeps some players under two ids: "mcdav" returned Wofford's
    /// Jamari McDavid as `4281043`, with a headshot, and again as
    /// "Jamari Mcdavid", `4902079`, without one (2026-11-06). The first is
    /// kept, because ESPN ranked it higher. Two different people with one
    /// name on one roster would lose a row here, which is rarer than the
    /// duplicate it prevents.
    ///
    /// The pro leagues aren't filtered. Their directories are complete and
    /// their slugs exact, so a name that failed to match there would be a
    /// string bug dropping a real player, not a division this app doesn't
    /// cover. And a college league whose directory has no teams is let
    /// through whole: that league's standings request failed, which says
    /// nothing about who plays in it, so the filter can't judge.
    nonisolated static func inScope(_ athletes: [PlayerIdentity],
                                    collegeTeams: [League: Set<String>]) -> [PlayerIdentity] {
        var seen = Set<String>()
        return athletes.filter { player in
            let person = [player.league.pathSegment, player.name, player.teamName ?? ""]
                .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
                .joined(separator: "|")
            guard seen.insert(person).inserted else {
                return false
            }
            guard player.league.isCollege,
                  let teams = collegeTeams[player.league], !teams.isEmpty else { return true }
            guard let team = player.teamName else { return false }
            return teams.contains(team)
        }
    }

    /// A failed request leaves `athletes` empty and says nothing on screen.
    /// Deliberate: the rest of search still works, and a network error
    /// banner over a working team list would be the loudest thing on a
    /// screen whose whole job is speed.
    func clear() {
        task?.cancel()
        query = ""
        athletes = []
        stories = []
        isSearching = false
    }
}
