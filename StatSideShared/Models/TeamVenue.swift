import Foundation

/// A team's home ground, derived from the season it already fetched.
///
/// ESPN's team-schedule payload ships a venue on **every** competition,
/// played or not (verified against all four leagues' captured schedules,
/// and against pre-state scoreboard events, which are the same shape), so
/// the home ground costs no request at all — it is the venue the team's
/// own non-neutral home dates keep naming.
///
/// What that payload does **not** carry is the venue `id` or `grass`, so
/// there is no surface here and no way to reach the core API's venue
/// resource from it. That is no loss: ESPN publishes no capacity anywhere
/// (sampled live 2026-09-10 across all four leagues, 100 core venue
/// objects carried one zero times), which is why the per-venue request the
/// game page once made was deleted. **Don't add one back.**
///
/// The crowd number is a season average rather than one game's gate,
/// because that is the only attendance figure that belongs to a *team*
/// rather than to a fixture.
nonisolated struct TeamVenue: Hashable, Sendable {
    let name: String
    /// "Athens, GA" — whatever of the address ESPN shipped, joined.
    let city: String?
    /// Home dates at this ground this season, played or still to come.
    let homeGames: Int
    /// How many of those have a published gate — the average's own
    /// denominator, and the reason it can be trusted.
    let countedGames: Int
    /// Mean announced attendance across `countedGames`. Nil before the
    /// first home date of the season has been played.
    let averageAttendance: Int?

    /// One of the team's fixtures, reduced to what the venue reads.
    struct Fixture: Sendable {
        let venue: String?
        let city: String?
        let isHome: Bool
        let isNeutral: Bool
        let attendance: Int?
    }

    /// The ground a team keeps coming back to.
    ///
    /// Modal rather than first-seen, so a one-off relocation — a hurricane
    /// week, a stadium being re-turfed — can't rename a team's home for
    /// the season; ties break toward the earlier date. Neutral sites are
    /// out by definition, which is what keeps Georgia's home Sanford
    /// Stadium rather than the Mercedes-Benz Stadium it opens in.
    static func home(from fixtures: [Fixture]) -> TeamVenue? {
        let hosted = fixtures.filter { $0.isHome && !$0.isNeutral && $0.venue != nil }
        guard !hosted.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (index, fixture) in hosted.enumerated() {
            guard let venue = fixture.venue else { continue }
            counts[venue, default: 0] += 1
            if firstSeen[venue] == nil { firstSeen[venue] = index }
        }
        guard let name = counts.keys.max(by: { lhs, rhs in
            let (left, right) = (counts[lhs] ?? 0, counts[rhs] ?? 0)
            if left != right { return left < right }
            // Equal counts: the earlier date wins, so the pick is stable
            // rather than dictionary-ordered.
            return (firstSeen[lhs] ?? 0) > (firstSeen[rhs] ?? 0)
        }) else { return nil }

        let dates = hosted.filter { $0.venue == name }
        let gates = dates.compactMap(\.attendance).filter { $0 > 0 }
        return TeamVenue(
            name: name,
            // The address rides on every copy of the fixture; take the
            // first that actually carries one.
            city: dates.lazy.compactMap(\.city).first,
            homeGames: dates.count,
            countedGames: gates.count,
            averageAttendance: gates.isEmpty
                ? nil
                : Int((Double(gates.reduce(0, +)) / Double(gates.count)).rounded())
        )
    }

    /// "Athens, GA" from whichever halves ESPN shipped.
    static func cityLine(city: String?, state: String?) -> String? {
        let parts = [city, state].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
