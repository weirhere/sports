import Foundation

/// One line of a pro team's transaction wire — a trade, a signing, a
/// waiver, a practice-squad elevation — as ESPN wrote it.
///
/// **The sentence is the data.** ESPN's `/transactions` ships a date, a
/// team and one hand-typed sentence per record, and nothing else: no
/// athlete id, no from and to, no fee (probed 2026-09-27). The sentence
/// can hold several moves ("Waived G DJ Armstrong. Acquired Gs Buddy
/// Hield…"), carries typos ("PLaced", "Elevate") and once credited a trade
/// to the Cleveland Guardians. So the row prints it verbatim, and the only
/// thing read out of it is each move's leading verb — enough to bold it and
/// to decide what the default filter shows. A route line built by parsing
/// that prose would be wrong in silence; a sentence can't be.
nonisolated struct RosterMove: Identifiable, Hashable, Sendable {
    /// Stable across page loads, so a page that shifted under a newer move
    /// can't list the same row twice.
    let id: String
    /// A local start-of-day. ESPN files every move at a placeholder instant
    /// (`07:00Z`, midnight Pacific), so the calendar date is the only real
    /// part of it — see `RosterMovesMapper.day(from:)`. Nil where the
    /// payload's date doesn't parse; the row still shows, under "Date TBA".
    let day: Date?
    /// Nil on a team-filtered response, which omits the team object; the
    /// team page doesn't draw it anyway.
    let team: Team?
    let text: String

    /// What the default view is for (the brief's D7).
    enum Kind: Hashable, Sendable {
        /// Signed, re-signed, acquired, traded, claimed — and anything whose
        /// verb we don't recognise, so a typo can never hide a trade.
        case signingOrTrade
        /// Every move in the sentence is roster upkeep: waivers, releases,
        /// injured-reserve moves, practice-squad elevations, assignments.
        case routine
    }

    /// The Trades tab's two views. Session-scoped on the page that shows it.
    enum Filter: Hashable, Sendable {
        case signingsAndTrades
        case all

        func shows(_ move: RosterMove) -> Bool {
            self == .all || move.kind == .signingOrTrade
        }
    }

    /// Each move in the sentence, as a range of `text` whose first word is
    /// its verb.
    let moves: [Range<String.Index>]
    let kind: Kind

    init(id: String, day: Date?, team: Team?, text: String) {
        self.id = id
        self.day = day
        self.team = team
        self.text = text
        self.moves = RosterMoveText.moves(in: text)
        self.kind = RosterMoveText.kind(of: text, moves: moves)
    }

    /// The leading verb of each move — the words the row sets in semibold.
    var verbRanges: [Range<String.Index>] {
        moves.compactMap { RosterMoveText.firstWordRange(in: text, within: $0) }
    }
}

/// The little reading the app does of ESPN's sentence. Pure, so the
/// splitting and the filter rule are testable against real wire copy.
nonisolated enum RosterMoveText {
    /// Verbs that make a move worth the default view. A coaching change
    /// ("Hired", "Fired" — the NBA's wire carries them) is news too.
    static let signingOrTradeVerbs: Set<String> = [
        "signed", "re-signed", "resigned", "acquired", "traded", "agreed",
        "claimed", "received", "hired", "fired", "named",
    ]

    /// Verbs that are roster upkeep. Includes ESPN's own misspellings and
    /// variants, seen live 2026-09-27 ("elevate", "elevating", "elevation").
    static let routineVerbs: Set<String> = [
        "waived", "released", "placed", "elevated", "elevate", "elevating",
        "elevation", "assigned", "reassigned", "recalled", "loaned", "activated",
        "designated", "suspended", "reinstated", "promoted", "terminated",
        "converted", "returned", "removed", "optioned", "sent",
    ]

    /// A word, lowercased, with trailing punctuation dropped: "PLaced" and
    /// "Signed," both read.
    static func verb(_ word: Substring) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    static func isKnownVerb(_ word: Substring) -> Bool {
        let verb = verb(word)
        return signingOrTradeVerbs.contains(verb) || routineVerbs.contains(verb)
    }

    /// The sentence split into moves. A new move starts only after ". "
    /// **and** at a word we know to be a verb, because the wire's names are
    /// full of full stops — "G C.J. Hanson", "Tyrone Marshall Jr.." — and a
    /// split at every one would bold "Hanson" as if it were an action.
    static func moves(in text: String) -> [Range<String.Index>] {
        guard !text.isEmpty else { return [] }
        var starts: [String.Index] = [text.startIndex]
        var search = text.startIndex
        while let stop = text.range(of: ". ", range: search..<text.endIndex) {
            let next = stop.upperBound
            let word = text[next...].prefix { !$0.isWhitespace }
            if isKnownVerb(word) { starts.append(next) }
            search = next
        }
        let ends = Array(starts.dropFirst()) + [text.endIndex]
        return zip(starts, ends).map { $0..<$1 }
    }

    /// A move's first word, if it has one.
    static func firstWordRange(in text: String, within range: Range<String.Index>) -> Range<String.Index>? {
        let slice = text[range]
        guard let start = slice.firstIndex(where: { !$0.isWhitespace }) else { return nil }
        let end = slice[start...].firstIndex(where: \.isWhitespace) ?? slice.endIndex
        return start..<end
    }

    /// Routine only when **every** move in the sentence leads with a known
    /// upkeep verb. One signing, one trade or one word we can't read puts
    /// the row in the default view: it fails open, so the filter can hide
    /// noise but never news.
    static func kind(of text: String, moves: [Range<String.Index>]) -> RosterMove.Kind {
        guard !moves.isEmpty else { return .signingOrTrade }
        let allRoutine = moves.allSatisfy { range in
            guard let word = firstWordRange(in: text, within: range) else { return false }
            return routineVerbs.contains(verb(text[word]))
        }
        return allRoutine ? .routine : .signingOrTrade
    }
}
