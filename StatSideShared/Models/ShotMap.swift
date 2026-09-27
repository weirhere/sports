import Foundation

/// The basketball and hockey Gamecast's picture (2026-09-27): this
/// period's shots where they were taken, on a surface drawn landscape and
/// whole, away team shooting right. Football's field is a strip because
/// its payload only has yard lines; these two get their full proportions
/// because every shot carries an x and a y (the pattern brief's D5, D14).
///
/// Every mark is already in surface units, so the views only scale:
/// - **Court**, 94 × 50 feet: x along the length from the left baseline,
///   y across. ESPN folds every shot onto one half (x across, y out from
///   the baseline), so each is unfolded to the basket its team attacks —
///   home at the left, away at the right, a half-turn apart.
/// - **Rink**, 200 × 85 feet: x from the left boards, y from the top.
///   Teams change ends every period, so a period whose away shots lean
///   left is turned a half-turn to keep the away team shooting right.
nonisolated struct ShotMap: Hashable, Sendable {
    enum Surface: Hashable, Sendable {
        case court, rink

        var size: (width: Double, height: Double) {
            switch self {
            case .court: (94, 50)
            case .rink: (200, 85)
            }
        }
    }

    /// Shape carries the outcome and color the team, so no mark relies on
    /// color alone (D10).
    enum Outcome: Hashable, Sendable {
        /// A made basket, or a hockey shot on goal that was saved.
        case made
        case missed
        case blocked
        case goal
    }

    struct Mark: Identifiable, Hashable, Sendable {
        let id: String
        let side: ScoringSide
        let x: Double
        let y: Double
        let outcome: Outcome
    }

    let surface: Surface
    let period: Int
    /// Oldest first; the last is the one the pin sits on.
    let marks: [Mark]

    var latest: Mark? { marks.last }
}

extension ShotMap {
    /// This period's map, or nil where there's nothing to draw: a league
    /// with no surface, a feed with no period yet, or a shootout (a
    /// shootout's attempts aren't a period's play and would redraw the
    /// same net a dozen times).
    static func current(plays: [Play], league: League, awayId: String?,
                        allowsShootout: Bool) -> ShotMap? {
        guard let surface = surface(for: league),
              let period = plays.last(where: { $0.period != nil })?.period,
              !(allowsShootout && league == .nhl && period == 5) else { return nil }
        let inPeriod = plays.filter { $0.period == period }
        func side(_ play: Play) -> ScoringSide? {
            guard let team = play.teamId else { return nil }
            return team == awayId ? .away : .home
        }
        switch surface {
        case .court:
            let marks: [Mark] = inPeriod.compactMap { play in
                guard play.isShootingPlay, let spot = play.coordinate,
                      let side = side(play) else { return nil }
                let (x, y) = side == .home ? (spot.y, spot.x) : (94 - spot.y, 50 - spot.x)
                return Mark(id: play.id, side: side, x: clamp(x, 94), y: clamp(y, 50),
                            outcome: play.isScoringPlay ? .made : .missed)
            }
            return ShotMap(surface: .court, period: period, marks: marks)
        case .rink:
            let attempts: [(Play, ScoringSide, PlayCoordinate, Outcome)] = inPeriod.compactMap { play in
                guard let spot = play.coordinate, let side = side(play),
                      let outcome = hockeyOutcome(play.typeText) else { return nil }
                return (play, side, spot, outcome)
            }
            // Which way the away team is shooting this period, by vote:
            // an away attempt right of center or a home attempt left of it
            // says "as drawn". Blocked shots sit out — their spot is the
            // block, which can be anywhere in the zone.
            let vote = attempts.filter { $0.3 != .blocked }.reduce(0.0) { total, attempt in
                let x = attempt.2.x
                return total + (attempt.1 == .away ? x : -x).unitSign
            }
            let turned = vote < 0
            let marks = attempts.map { play, side, spot, outcome in
                let x = turned ? -spot.x : spot.x
                let y = turned ? -spot.y : spot.y
                return Mark(id: play.id, side: side, x: clamp(x + 100, 200),
                            y: clamp(42.5 - y, 85), outcome: outcome)
            }
            return ShotMap(surface: .rink, period: period, marks: marks)
        }
    }

    static func surface(for league: League) -> Surface? {
        switch league {
        case .nba: .court
        case .nhl: .rink
        case .collegeFootball, .nfl: nil
        }
    }

    /// ESPN's hockey play types that are shot attempts. Everything else —
    /// faceoffs, hits, giveaways, penalties — isn't drawn.
    static func hockeyOutcome(_ type: String?) -> Outcome? {
        switch type?.lowercased() {
        case "shot": .made
        case "goal": .goal
        case "missed": .missed
        case "blocked": .blocked
        default: nil
        }
    }

    private static func clamp(_ value: Double, _ upper: Double) -> Double {
        min(max(value, 0), upper)
    }
}

private extension Double {
    /// -1, 0 or 1.
    var unitSign: Double { self > 0 ? 1 : (self < 0 ? -1 : 0) }
}
