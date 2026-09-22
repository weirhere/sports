import Foundation

/// Who a player is, and everything the screen that linked to them already
/// knew about them.
///
/// **Deliberately not a fetched model.** ESPN's athlete endpoints are
/// unprobed — see E20's P0 — so the only facts the app can state about a
/// player today are the ones a roster row already holds. A roster row holds
/// all of them, which is why the roster is the one door open in this first
/// cut: a box score row knows a name, a number and a stat line, and a page
/// built from that would be the row again.
///
/// The athlete id is ESPN's own and is the same value a box score row
/// carries (`BoxScore.Player.id` where ESPN sent one), so the other doors
/// open onto this same identity when there is something behind them.
nonisolated struct PlayerIdentity: Sendable, Hashable, Identifiable {
    let athleteId: String
    let name: String
    let league: League
    /// The team this player was reached through — a roster belongs to one.
    let teamName: String?
    /// A `var` since 2026-09-21: search knows a club's name but not its
    /// crest, so the player page backfills this once the athlete payload's
    /// team id resolves through the directory. `team` beside it is a `var`
    /// for the same class of reason.
    var teamLogoURL: URL?
    /// The same team as a pushable value, so the hero's team badge has
    /// somewhere to go (2026-09-20). `TeamPage` is registered for `Team` in
    /// every stack a player page can appear in, so this needs no destination
    /// of its own.
    ///
    /// A `var` with a default rather than a `let`, for `Team.league`'s
    /// reason: Swift omits defaulted `let` properties from the memberwise
    /// init, and the doors that know a name but not the team — a box score
    /// row, when that door opens — construct one without this.
    var team: Team?

    var jersey: String?
    var position: String?
    var positionName: String?
    var height: String?
    var weight: String?
    var age: Int?
    var classAbbreviation: String?
    var headshotURL: URL?
    var injuryStatus: String?

    /// Namespaced by league the way `FollowKey` is, and for the same reason:
    /// two leagues can reuse an athlete id, and this value is a navigation
    /// identity. A destination whose identity doesn't change is reused with
    /// its `@State` intact (2026-09-10), which is how one entity's page came
    /// to render another's.
    var id: String { "\(league.rawValue)-\(athleteId)" }
}

nonisolated extension PlayerIdentity {
    /// The roster row's own facts, carried into the page it now pushes.
    init(player: RosterPlayer, team: Team, league: League) {
        self.init(athleteId: player.id,
                  name: player.name,
                  league: league,
                  // The app's one team name (2026-09-21), so the page a
                  // roster opens and the page search opens name the same
                  // club the same way.
                  teamName: team.displayName ?? team.location,
                  teamLogoURL: team.logoURL,
                  team: team,
                  jersey: player.jersey,
                  position: player.position,
                  positionName: player.positionName,
                  height: player.height,
                  weight: player.weight,
                  age: player.age,
                  classAbbreviation: player.classAbbreviation,
                  headshotURL: player.headshotURL,
                  injuryStatus: player.injuryStatus)
    }

    /// Profile's label/value pairs, in the design's order, skipping whatever
    /// ESPN didn't send rather than printing a dash.
    ///
    /// The third row is the league's own, for `RosterMetric`'s reason:
    /// college football publishes no age at all and a class year instead, so
    /// an Age row there would label a value that never arrives.
    ///
    /// **No hometown row.** The design draws one; no payload we hold carries
    /// a `birthPlace` and the fixtures are trimmed, so its source is unknown
    /// rather than absent. The row lands when the probe finds it.
    var profileRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let height, !height.isEmpty { rows.append((label: "Height", value: height)) }
        if let weight, !weight.isEmpty { rows.append((label: "Weight", value: weight)) }
        switch league.rosterMetric {
        case .age:
            if let age { rows.append((label: "Age", value: String(age))) }
        case .classYear:
            if let classAbbreviation, !classAbbreviation.isEmpty {
                // `spoken` maps the four known abbreviations and passes
                // anything else straight back, so capitalizing blindly would
                // turn an unmapped "GR" into "Gr". Only a mapped value has a
                // long form to capitalize.
                let spoken = RosterMetric.classYear.spoken(classAbbreviation)
                let value = spoken == classAbbreviation ? classAbbreviation : spoken.capitalized
                rows.append((label: "Class", value: value))
            }
        }
        if let positionName, !positionName.isEmpty {
            rows.append((label: "Position", value: positionName))
        }
        if let jersey, !jersey.isEmpty { rows.append((label: "Jersey", value: jersey)) }
        if let injuryStatus, !injuryStatus.isEmpty {
            rows.append((label: "Status", value: injuryStatus))
        }
        return rows
    }

    /// One sentence for the hero, so VoiceOver doesn't read a name and then
    /// an unlabelled run of abbreviations — `RosterRow`'s rule.
    ///
    /// Name and club, which is exactly what the hero draws (2026-09-21).
    /// It used to speak the number and the position too, from the days when
    /// the hero printed them; now that they are Profile rows, so is their
    /// spoken form — a label that announces facts the screen doesn't show
    /// makes the page longer to hear than to read, and the rows below say
    /// both with their own names attached.
    var spokenSummary: String {
        var parts: [String] = [name]
        if let teamName, !teamName.isEmpty { parts.append(teamName) }
        return parts.joined(separator: ", ")
    }
}
