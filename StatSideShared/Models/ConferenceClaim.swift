import Foundation

/// Deciding which conference a team page may claim.
///
/// A team's own payload names a conference, and usually that's the end of
/// it. The exception is a team the app's directory has never heard of: it
/// is, by construction, outside the divisions we fetch, and a group id it
/// reports could mean something different from the same number in our
/// table. So the claim is checked — but **disproof-shaped**, which is the
/// part that has been got wrong twice:
///
/// - The first version was "know the team or show nothing". That stripped
///   every Sun Belt page of its conference line and Standings tab, because
///   ESPN ships the Sun Belt with zero standings entries and so the
///   directory has never heard of any of its members (2026-08-29).
/// - So an empty roster proves nothing. The claim falls only when the
///   directory can actually *disprove* it: the claimed conference has a
///   roster, and this team isn't on it.
///
/// The rule survived E8 unchanged; its **reason** did not. The original
/// worry was that "an FCS opponent's payload can reuse a group id that
/// collides with our FBS table", and that is now provably not a thing:
/// the two divisions' ids are disjoint (asserted in `FCSRegistryTests`)
/// and the directory knows all 116 FCS teams, so an FCS team is no longer
/// an unknown one. What's left to defend against is narrower and real —
/// a team in *neither* division (a D-II or D-III opponent on someone's
/// schedule), and any team ESPN drops from a conference whose other
/// members it still lists.
///
/// SWAC is the live proof the shape matters: zero standings entries today,
/// so none of its teams are in the directory, so their claims are
/// unfalsifiable and stand. They get their conference line. The moment
/// ESPN ships SWAC entries, the same rule starts checking them.
nonisolated enum ConferenceClaim {
    /// The conference id a team page should use, or nil to show none.
    ///
    /// - Parameters:
    ///   - claimed: the id the team's own payloads report.
    ///   - teamId: the team being shown.
    ///   - directory: every team the app knows, both divisions. Empty
    ///     before the directory loads, which must never veto anything.
    static func resolve(claimed: Int?, teamId: String, directory: [Team]) -> Int? {
        guard let claimed else { return nil }
        guard !directory.isEmpty else { return claimed }
        // Known team: its claim is as good as the directory's own data.
        guard !directory.contains(where: { $0.id == teamId }) else { return claimed }
        // Unknown team: only a rostered conference can disprove it.
        let rostered = directory.contains { $0.conferenceId == claimed }
        return rostered ? nil : claimed
    }
}
