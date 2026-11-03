import Foundation

/// Where a live baseball game stands, read off ESPN's play feed
/// (2026-11-03): who's on, how many out, the count, who's batting against
/// whom, and the last pitch. The Gamecast's diamond is drawn from this.
///
/// Built from the feed rather than the scoreboard's `situation`, which was
/// null on every final probed and can't be seen live until spring training.
/// The feed carries everything on every play, verified against the 2026
/// World Series' Game 5 (`mlb-summary.json`):
///
/// - **Runners** are the play's `onFirst`/`onSecond`/`onThird` participants,
///   and they describe the bases *after* the play: Pratt's single lists
///   Frelick on third, where the single put him. A pitch or a "Start
///   Batter/Pitcher" lists who's on now. So the latest play is the truth.
/// - **Outs** are stamped per at-bat, with the outs that stood when it
///   ended — every pitch of a strikeout already says the out it ends in.
///   So outs come from the latest *finished* at-bat in this half, and an
///   at-bat still being pitched to doesn't count its own.
/// - **The count** is the latest pitch's `resultCount`.
nonisolated struct BaseballDiamond: Hashable, Sendable {
    let inning: Int?
    let half: InningHalf?
    let onFirst: Bool
    let onSecond: Bool
    let onThird: Bool
    let outs: Int
    let balls: Int?
    let strikes: Int?
    let batterId: String?
    let pitcherId: String?
    /// The side batting this half: the away team in the top.
    let battingSide: ScoringSide?
    /// "96 mph Four-seam FB".
    let lastPitch: String?
    /// The latest at-bat's outcome, ESPN's sentence.
    let lastResult: String?
    /// The play that state was read off — what keys the surface's
    /// redraw.
    let playId: String?

    /// Between halves ("Middle 5th", "End 5th"): nobody's batting, the
    /// bases are clear, and the count is nobody's.
    var isBreak: Bool { half == .middle || half == .end }

    /// "Top 5th", "Mid 5th" — the sport's own way of saying where a game
    /// is, as ESPN's status line spells it.
    var inningText: String? {
        guard let inning, let half else { return nil }
        let word = switch half {
        case .top: "Top"
        case .bottom: "Bot"
        case .middle: "Mid"
        case .end: "End"
        }
        return "\(word) \(GameStatus.periodLabel(inning, in: .mlb))"
    }

    /// The state after the latest play, or nil for a feed with no
    /// baseball in it (every other league) or nothing played yet.
    static func current(plays: [Play]) -> BaseballDiamond? {
        guard let last = plays.last(where: { $0.baseball != nil }) else { return nil }
        let half = last.half
        let inning = last.period
        let inHalf = plays.filter { $0.baseball != nil && $0.period == inning && $0.half == half }
        let isBreak = half == .middle || half == .end

        let roles = Set(last.participants.compactMap(\.role))
        // The latest at-bat in this half that has ended: its outs are the
        // outs that stand, whether the latest play is its result or a
        // pitch to the next batter. None ended yet means none out.
        let finished = inHalf.last { play in
            guard let state = play.baseball else { return false }
            return state.isResult || state.kind == "end-batterpitcher"
        }
        let outs = isBreak ? 0 : (finished?.baseball?.outs ?? 0)
        let matchup = inHalf.last { play in
            play.participants.contains { $0.role == "batter" || $0.role == "pitcher" }
        }
        func athlete(_ role: String) -> String? {
            matchup?.participants.first { $0.role == role }?.athleteId
        }
        let pitch = inHalf.last { $0.baseball?.isPitch == true }
        let result = plays.last { $0.baseball?.isResult == true }
        let side: ScoringSide? = switch half {
        case .top: .away
        case .bottom: .home
        default: nil
        }

        return BaseballDiamond(
            inning: inning,
            half: half,
            onFirst: !isBreak && roles.contains("onFirst"),
            onSecond: !isBreak && roles.contains("onSecond"),
            onThird: !isBreak && roles.contains("onThird"),
            outs: min(max(outs, 0), 3),
            balls: isBreak ? nil : last.baseball?.balls,
            strikes: isBreak ? nil : last.baseball?.strikes,
            batterId: isBreak ? nil : athlete("batter"),
            pitcherId: isBreak ? nil : athlete("pitcher"),
            battingSide: side,
            lastPitch: isBreak ? nil : pitch.flatMap(Self.pitchLine),
            lastResult: result?.text,
            playId: last.id)
    }

    /// "96 mph Four-seam FB" — the speed where ESPN has one.
    static func pitchLine(_ play: Play) -> String? {
        guard let state = play.baseball, let type = state.pitchType else { return nil }
        guard let speed = state.pitchVelocity, speed > 0 else { return type }
        return "\(speed) mph \(type)"
    }
}

extension GamecastContent {
    /// Baseball's card (2026-11-03): Count · Outs · Pitch over the diamond,
    /// with the matchup and the last result beneath. `names` resolves an
    /// athlete id to a name — the box score's athletes, which hold everyone
    /// who has batted or pitched.
    static func baseball(diamond: BaseballDiamond, summary: GameSummary,
                         names: [String: String]) -> GamecastContent {
        let batter = diamond.batterId.flatMap { names[$0] }
        let pitcher = diamond.pitcherId.flatMap { names[$0] }
        let count = diamond.balls.flatMap { balls in diamond.strikes.map { "\(balls)-\($0)" } }
        let outs = diamond.isBreak ? nil : (diamond.outs == 1 ? "1 out" : "\(diamond.outs) outs")
        let matchup: String = {
            switch (batter, pitcher) {
            case let (batter?, pitcher?): return "\(batter) vs \(pitcher)"
            case let (batter?, nil): return "\(batter) batting"
            case let (nil, pitcher?): return "\(pitcher) pitching"
            default: return "Last play"
            }
        }()
        var spoken: [String] = [diamond.inningText].compactMap(\.self)
        if !diamond.isBreak {
            let bases = [(diamond.onFirst, "first"), (diamond.onSecond, "second"), (diamond.onThird, "third")]
                .filter(\.0).map(\.1)
            spoken.append(bases.isEmpty ? "bases empty" : "runners on " + bases.joined(separator: " and "))
            if let outs { spoken.append(outs) }
            if let count { spoken.append("count \(count)") }
            if batter != nil || pitcher != nil { spoken.append(matchup) }
        }
        if let text = diamond.lastResult { spoken.append(text) }
        return GamecastContent(
            slots: [GamecastSlot(label: "Count", value: count),
                    GamecastSlot(label: "Outs", value: outs.map { _ in "\(diamond.outs)" }),
                    GamecastSlot(label: "Pitch", value: diamond.lastPitch)],
            lastPlayLabel: diamond.isBreak ? "Last play" : matchup,
            lastPlayClock: diamond.inningText,
            lastPlayText: diamond.lastResult,
            accessibilitySummary: spoken.joined(separator: ", "))
    }
}

extension GameSummary {
    /// Every athlete the box score names, by id — the batters and pitchers
    /// a baseball play's participants point at with ids alone.
    var athleteNames: [String: String] {
        var names: [String: String] = [:]
        for team in boxScore {
            for category in team.categories {
                for player in category.players {
                    if let id = player.athleteId { names[id] = player.name }
                }
            }
        }
        return names
    }
}
