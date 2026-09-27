import Foundation

/// One of the Gamecast card's three header columns: "DOWN / 2nd & 4",
/// "SHOTS / 10–7". A missing value prints "—" rather than dropping the
/// column, so the other two never move (D2, D3).
nonisolated struct GamecastSlot: Hashable, Sendable {
    let label: String
    let value: String?
}

/// Everything the Gamecast card prints, whatever the league (2026-09-27,
/// the pattern brief): three slots or the result line in their place, the
/// surface beneath them, and the last play. The card never asks which
/// league it's showing; each league builds one of these.
nonisolated struct GamecastContent: Hashable, Sendable {
    /// Always three.
    let slots: [GamecastSlot]
    /// "Touchdown", "Goal" — shown in the slots' place while it stands.
    var result: String? = nil
    var resultTeam: Team? = nil
    /// "Last play · 2nd & 15 at WSU 48", "Last play · Power play".
    let lastPlayLabel: String
    let lastPlayClock: String?
    let lastPlayText: String?
    /// The card is one VoiceOver element and this is what it says.
    let accessibilitySummary: String
}

// MARK: - Football

extension GamecastContent {
    /// The drive card as it shipped: Down · Ball on · Drive.
    init(situation: GameSituation, summary: GameSummary) {
        let offense = summary.team(withId: situation.possessionTeamId)
        var parts: [String] = []
        if let result = situation.result {
            let scorer = summary.team(withId: situation.resultTeamId)?.location
            parts.append([scorer, result.lowercased()].compactMap(\.self).joined(separator: " "))
        } else {
            if let name = offense?.location { parts.append("\(name) ball") }
            if let down = situation.downDistanceText { parts.append(down) }
            if let spot = situation.possessionText { parts.append(spot) }
            if let line = situation.driveLine { parts.append(line) }
        }
        if let text = situation.lastPlayText { parts.append(text) }
        self.init(
            slots: [GamecastSlot(label: "Down", value: situation.downDistanceText),
                    GamecastSlot(label: "Ball on", value: situation.possessionText),
                    GamecastSlot(label: "Drive", value: situation.driveLine)],
            result: situation.result,
            resultTeam: summary.team(withId: situation.resultTeamId),
            lastPlayLabel: ["Last play", situation.lastPlayDownText]
                .compactMap(\.self).joined(separator: " · "),
            lastPlayClock: situation.lastPlayClock,
            lastPlayText: situation.lastPlayText,
            accessibilitySummary: parts.joined(separator: ", ")
        )
    }
}

// MARK: - Basketball and hockey

extension GamecastContent {
    /// The card for a league drawn as a shot map, or nil for one that
    /// isn't, or a feed with nothing played yet.
    static func shotMap(summary: GameSummary, league: League,
                        allowsShootout: Bool) -> GamecastContent? {
        guard let last = summary.plays.last else { return nil }
        switch league {
        case .nba: return basketball(summary: summary, last: last)
        case .nhl: return hockey(summary: summary, last: last, allowsShootout: allowsShootout)
        case .collegeFootball, .nfl: return nil
        }
    }

    // MARK: Basketball — Run · Lead · Lead changes

    private static func basketball(summary: GameSummary, last: Play) -> GamecastContent {
        let away = summary.away?.team
        let home = summary.home?.team
        func abbr(_ side: ScoringSide) -> String {
            (side == .away ? away : home).flatMap(\.abbreviation) ?? (side == .away ? "Away" : "Home")
        }
        func name(_ side: ScoringSide) -> String {
            (side == .away ? away : home)?.location ?? abbr(side)
        }
        let run = Self.run(in: summary.plays)
        let margin = Self.margin(in: summary.plays)
        let changes = Self.leadChanges(in: summary.plays)

        let leadText: String? = margin.map { m in
            m == 0 ? "Tied" : "\(abbr(m > 0 ? .away : .home)) +\(abs(m))"
        }
        var spoken: [String] = []
        if let run { spoken.append("\(name(run.side)) on a \(run.points)–0 run") }
        if let margin {
            spoken.append(margin == 0 ? "tied" : "\(name(margin > 0 ? .away : .home)) up \(abs(margin))")
        }
        spoken.append("\(changes) lead \(changes == 1 ? "change" : "changes")")
        if let text = last.text { spoken.append(text) }

        return GamecastContent(
            slots: [GamecastSlot(label: "Run", value: run.map { "\(abbr($0.side)) \($0.points)–0" }),
                    GamecastSlot(label: "Lead", value: leadText),
                    GamecastSlot(label: "Lead changes", value: "\(changes)")],
            lastPlayLabel: "Last play",
            lastPlayClock: last.clock,
            lastPlayText: last.text,
            accessibilitySummary: spoken.joined(separator: ", ")
        )
    }

    /// The points one side has scored since the other last did. Nil
    /// before anyone scores.
    static func run(in plays: [Play]) -> (side: ScoringSide, points: Int)? {
        var away = 0, home = 0
        var scores: [(ScoringSide, Int)] = []
        for play in plays {
            guard let a = play.awayScore, let h = play.homeScore else { continue }
            if a > away { scores.append((.away, a - away)) }
            if h > home { scores.append((.home, h - home)) }
            away = a
            home = h
        }
        guard let side = scores.last?.0 else { return nil }
        let points = scores.reversed().prefix { $0.0 == side }.reduce(0) { $0 + $1.1 }
        return (side, points)
    }

    /// Away minus home at the last play that carried a score.
    static func margin(in plays: [Play]) -> Int? {
        guard let play = plays.last(where: { $0.awayScore != nil && $0.homeScore != nil }),
              let a = play.awayScore, let h = play.homeScore else { return nil }
        return a - h
    }

    /// How many times the lead has passed from one side to the other. A tie
    /// in between doesn't count on its own; the next lead decides.
    static func leadChanges(in plays: [Play]) -> Int {
        var leader = 0
        var changes = 0
        for play in plays {
            guard let a = play.awayScore, let h = play.homeScore, a != h else { continue }
            let now = a > h ? 1 : -1
            if leader != 0, now != leader { changes += 1 }
            leader = now
        }
        return changes
    }

    // MARK: Hockey — Strength · Shots · Last goal

    private static func hockey(summary: GameSummary, last: Play,
                               allowsShootout: Bool) -> GamecastContent {
        let awayTeam = summary.away?.team
        let homeTeam = summary.home?.team
        let awayId = awayTeam?.id
        let plays = summary.plays.filter { !(allowsShootout && $0.period == 5) }
        func team(_ id: String?) -> Team? { id == nil ? nil : (id == awayId ? awayTeam : homeTeam) }
        func other(_ id: String?) -> Team? { id == nil ? nil : (id == awayId ? homeTeam : awayTeam) }
        func remaining(_ play: Play) -> String? {
            remainingClock(elapsed: play.clock, period: play.period, allowsShootout: allowsShootout)
        }

        // Strength, from the last play's team's side: their power play,
        // or the other side's when they're the ones short.
        let strength: (value: String?, spoken: String?, label: String?) = {
            switch last.strength {
            case "even-strength": return ("Even", "Even strength", nil)
            case "power-play":
                let t = team(last.teamId)
                return (t?.abbreviation.map { "\($0) PP" } ?? "PP",
                        "\(t?.location ?? "") power play".trimmingCharacters(in: .whitespaces),
                        "Power play")
            case "short-handed":
                let t = other(last.teamId)
                return (t?.abbreviation.map { "\($0) PP" } ?? "PP",
                        "\(t?.location ?? "") power play".trimmingCharacters(in: .whitespaces),
                        "Power play")
            case "empty-net": return ("Empty net", "Empty net", "Empty net")
            default: return (nil, nil, nil)
            }
        }()

        var shots = (away: 0, home: 0)
        for play in plays where ["shot", "goal"].contains(play.typeText?.lowercased() ?? "") {
            if play.teamId == awayId { shots.away += 1 } else if play.teamId != nil { shots.home += 1 }
        }

        let goalIndex = plays.lastIndex { $0.typeText?.lowercased() == "goal" }
        let goal = goalIndex.map { plays[$0] }
        let lastGoalText: String? = goal.map { goal in
            let who = team(goal.teamId)?.abbreviation ?? ""
            let when = goal.period == last.period
                ? remaining(goal)
                : goal.period.map { GameStatus.periodLabel($0, in: .nhl) }
            return [who, when].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " ")
        }
        // A goal holds the header until play restarts with a faceoff, the
        // way a touchdown holds it until the next snap (D4).
        let faceoffIndex = plays.lastIndex { $0.typeText?.lowercased() == "face off" }
        let goalStands = goalIndex.map { $0 > (faceoffIndex ?? -1) && goal?.period == last.period } ?? false

        var spoken: [String] = []
        if goalStands, let goal { spoken.append("\(team(goal.teamId)?.location ?? "") goal".trimmingCharacters(in: .whitespaces)) }
        else if let s = strength.spoken { spoken.append(s) }
        spoken.append("shots \(awayTeam?.location ?? "away") \(shots.away), \(homeTeam?.location ?? "home") \(shots.home)")
        if let text = last.text { spoken.append(text) }

        return GamecastContent(
            slots: [GamecastSlot(label: "Strength", value: strength.value),
                    GamecastSlot(label: "Shots", value: "\(shots.away)–\(shots.home)"),
                    GamecastSlot(label: "Last goal", value: lastGoalText)],
            result: goalStands ? "Goal" : nil,
            resultTeam: goalStands ? team(goal?.teamId) : nil,
            lastPlayLabel: ["Last play", strength.label].compactMap(\.self).joined(separator: " · "),
            lastPlayClock: remaining(last),
            lastPlayText: last.text,
            accessibilitySummary: spoken.joined(separator: ", ")
        )
    }

    /// Time left in the period from ESPN's hockey play clock, which counts
    /// *up* ("0:29" is 29 seconds in). The header counts down, and the
    /// card must agree with it (D11). Twenty minutes a period; a regular
    /// season's overtime is five.
    static func remainingClock(elapsed: String?, period: Int?, allowsShootout: Bool) -> String? {
        guard let elapsed else { return nil }
        let parts = elapsed.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return elapsed }
        let length = (period ?? 1) > 3 && allowsShootout ? 5 * 60 : 20 * 60
        let left = max(0, length - (parts[0] * 60 + parts[1]))
        return String(format: "%d:%02d", left / 60, left % 60)
    }
}
