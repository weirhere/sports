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

nonisolated extension Game {
    /// What the share sheet carries. There's no per-game web page, so the
    /// text is the whole artifact — status-shaped like the row it came from.
    var shareText: String {
        func name(_ competitor: Competitor) -> String {
            guard let rank = competitor.rank else { return competitor.team.location }
            return "#\(rank) \(competitor.team.location)"
        }
        func scored(_ competitor: Competitor) -> String {
            "\(name(competitor)) \(competitor.score.map(String.init) ?? "–")"
        }

        let body: String
        switch status {
        case .pre:
            var parts = ["\(name(away)) at \(name(home))"]
            if let date {
                parts.append(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
            }
            if let broadcast {
                parts.append("on \(broadcast.split(separator: "/").first.map(String.init) ?? broadcast)")
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
            body = "\(name(away)) at \(name(home)), \(detail ?? "status unavailable")"
        }
        return ShareSignOff.appended(to: body)
    }
}
