import Foundation

nonisolated extension TeamSchedule {
    /// The next scheduled game: first .pre in the season, which both
    /// mappers already sort ascending by date. No wall-clock check — a
    /// stale .pre shares slightly old copy, never wrong data.
    var nextGame: Game? {
        games.first { if case .pre = $0.status { return true } else { return false } }
    }
}

nonisolated extension Team {
    /// The team-page share: an invitation to the recipient, not a status
    /// line about the sender. The sign-off already says "via StatSide",
    /// so the body never names the app. Every clause is optional — the
    /// share works before the schedule loads, and after the season ends.
    func shareText(schedule: TeamSchedule?) -> String {
        var body = "Keep up with \(displayName ?? location) this season"
        // 0-0 is hidden just like the page header — preseason records are noise.
        if let record = schedule?.record, record != "0-0" {
            body += " — \(record)"
        }
        if let next = schedule?.nextGame {
            let isHome = next.home.team.id == id
            let opponent = isHome ? next.away : next.home
            body += ". Next up: \(isHome ? "vs" : "at") \(opponent.shareName)"
            if let date = next.date {
                body += ", \(date.shareKickText)"
            }
            if let network = next.primaryBroadcast {
                body += " on \(network)"
            }
        }
        return ShareSignOff.appended(to: body)
    }
}
