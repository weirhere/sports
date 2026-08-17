import Foundation

/// How every share ends, wherever it was built from. The link goes on its
/// own line so the body stays one readable sentence and messaging apps
/// render a preview. Game detail composes its own body from the fresher
/// summary score — it signs off through here so the two can't drift.
nonisolated enum ShareSignOff {
    static let appStoreURL = "https://apps.apple.com/app/id6793266645"

    static func appended(to body: String) -> String {
        "\(body) — via StatSide\n\(appStoreURL)"
    }
}

nonisolated extension Competitor {
    /// "#3 Georgia" when ranked, plain "Georgia" when not.
    var shareName: String {
        guard let rank else { return team.location }
        return "#\(rank) \(team.location)"
    }
}

nonisolated extension Game {
    /// The first network of a multi-cast ("ESPN/ESPN2" → "ESPN").
    var primaryBroadcast: String? {
        broadcast.map { $0.split(separator: "/").first.map(String.init) ?? $0 }
    }
}

nonisolated extension Date {
    /// Kick times in shares stay absolute — the text outlives the moment
    /// it was generated, so no "Today"/"Tomorrow" (decisions log 2026-08-09).
    var shareKickText: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    /// The day alone, for kickoffs whose time is still a placeholder.
    var shareKickDayText: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

nonisolated extension Game {
    /// What the share sheet carries. There's no per-game web page, so the
    /// text is the whole artifact — status-shaped like the row it came from.
    var shareText: String {
        func scored(_ competitor: Competitor) -> String {
            "\(competitor.shareName) \(competitor.score.map(String.init) ?? "–")"
        }

        let body: String
        switch status {
        case .pre:
            var parts = ["\(away.shareName) at \(home.shareName)"]
            if let date {
                parts.append(timeTBD ? "\(date.shareKickDayText), time TBD" : date.shareKickText)
            }
            if let network = primaryBroadcast {
                parts.append("on \(network)")
            }
            body = parts.joined(separator: ", ")
        case .live(let clock, let period, let detail, _):
            let quarter = period.map { $0 <= 4 ? "Q\($0)" : ($0 == 5 ? "OT" : "\($0 - 4)OT") }
            let situation = [quarter, clock].compactMap(\.self).joined(separator: " ")
            let score = "\(scored(away)), \(scored(home))"
            body = situation.isEmpty ? "\(score), \(detail ?? "live")" : "\(score), \(situation)"
        case .final(let detail):
            let overtime = detail?.localizedCaseInsensitiveContains("OT") == true
            body = "Final\(overtime ? " (OT)" : ""): \(scored(away)), \(scored(home))"
        case .other(let detail):
            body = "\(away.shareName) at \(home.shareName), \(detail ?? "status unavailable")"
        }
        return ShareSignOff.appended(to: body)
    }
}
