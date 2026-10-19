import Foundation

/// A record with one game taken back off it — what a hidden final's teams
/// wear while spoiler mode holds the result (E30, 2026-10-19).
///
/// ESPN's scoreboard record is post-game the moment a game goes final, so
/// "7-0" beside a hidden Georgia row says Georgia won as plainly as the
/// score would. We hold the result, so the record can be rewound: the
/// winner gives back a win, the loser a loss. Hockey's third field is
/// overtime and shootout losses, so an NHL loser whose final reads "OT"
/// or "SO" gives back one of those instead; the NFL's third field is
/// ties, and a tie gives back a tie.
///
/// The record is a string in every payload, so this parses two or three
/// dash-separated numbers and hides the record (nil) for anything else, a
/// field that would go negative, or an outcome it can't tell. A wrong
/// record is a lie; no record is a blank.
nonisolated enum RecordRewind {
    /// `record` with one game removed for `competitor`'s outcome against
    /// `other`, or nil when it can't be done honestly. A live game's
    /// record is returned unchanged: the scoreboard's record is still the
    /// pre-game one until the final.
    static func rewound(_ record: String?, for competitor: Competitor, against other: Competitor,
                        status: GameStatus, league: League) -> String? {
        guard let record else { return nil }
        guard case .final(let detail) = status else { return record }
        guard let outcome = Outcome(competitor, against: other) else { return nil }
        let parsed = record.split(separator: "-", omittingEmptySubsequences: false)
            .map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parsed.count == 2 || parsed.count == 3, !parsed.contains(nil) else { return nil }
        var fields = parsed.compactMap(\.self)

        let index: Int
        switch outcome {
        case .won:
            index = 0
        case .lost:
            let beyondRegulation = detail.map {
                $0.localizedCaseInsensitiveContains("OT") || $0.localizedCaseInsensitiveContains("SO")
            } ?? false
            index = league == .nhl && beyondRegulation && fields.count == 3 ? 2 : 1
        case .tied:
            guard fields.count == 3 else { return nil }
            index = 2
        }
        fields[index] -= 1
        guard fields[index] >= 0 else { return nil }
        return fields.map(String.init).joined(separator: "-")
    }

    private enum Outcome {
        case won, lost, tied

        /// The winner flags first; failing those, the scores. Nil when
        /// neither says.
        init?(_ competitor: Competitor, against other: Competitor) {
            if competitor.winner == true { self = .won; return }
            if other.winner == true { self = .lost; return }
            guard let mine = competitor.score, let theirs = other.score else { return nil }
            if mine > theirs { self = .won } else if mine < theirs { self = .lost } else { self = .tied }
        }
    }
}
