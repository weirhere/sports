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
    /// `collegeTeamsInScope` is the display names of every college football
    /// team the app has a page for — FBS *and* FCS, which is what the
    /// directory loads. ESPN's `college-football` slug is wider than that:
    /// it indexes Division II and III too, so a "McDavid" query returns
    /// Mars Hill Lions beside Harvard Crimson. Harvard is a real FCS page
    /// here; Mars Hill is nothing, and a row that opens nothing is worse
    /// than no row. Verified 2026-09-21 against both standings groups —
    /// Tarleton State and Harvard are in group 81, Mars Hill is in neither.
    ///
    /// The directory is the arbiter rather than a hardcoded division list,
    /// so the day the app adds a division the filter follows it for free.
    func search(_ text: String, collegeTeamsInScope: Set<String>) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        task?.cancel()

        guard !trimmed.isEmpty else {
            // A cleared field costs no request and keeps no stale people.
            athletes = []
            isSearching = false
            return
        }

        isSearching = true
        task = Task { [weak self, client] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            let found = (try? await client.athletes(matching: trimmed,
                                                    limit: Self.limit)) ?? []
            guard !Task.isCancelled else { return }
            guard let self, self.query == trimmed else { return }
            self.athletes = found.filter { player in
                // Only college football is filtered. The three pro leagues
                // have complete directories and exact slugs, so a name that
                // failed to match there would be a string bug dropping a
                // real player rather than a division this app doesn't cover.
                guard player.league == .collegeFootball else { return true }
                guard let team = player.teamName else { return false }
                return collegeTeamsInScope.contains(team)
            }
            self.isSearching = false
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
        isSearching = false
    }
}
