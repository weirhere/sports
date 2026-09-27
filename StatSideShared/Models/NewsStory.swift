import Foundation

/// One story, as the News surfaces carry it (docs/news.md). Its photo is
/// the color budget's sixth exception (Andy, 2026-09-27), superseding N8's
/// text-only rule: full color, and only inside story cards, rows and the
/// reader's hero.
///
/// A story arrives two ways. The game summary's `article` comes whole, body
/// included, inside a request the game page already makes. A team feed's
/// items come as headlines only, and the body is one request to `bodyURL`
/// when the reader opens (N4).
nonisolated struct NewsStory: Identifiable, Hashable, Sendable {
    /// The ESPN story types the app shows (N10). `Media` is video that only
    /// plays in ESPN's own apps, and `Eticket` is ticket commerce, which the
    /// Icebox keeps out; both map to nil and never reach a list.
    enum Kind: String, CaseIterable, Hashable, Sendable {
        case recap = "Recap"
        case preview = "Preview"
        case headline = "HeadlineNews"
        case story = "Story"

        /// Case-blind: feeds say `HeadlineNews`, search says `headlinenews`.
        init?(espnType: String?) {
            guard let espnType,
                  let kind = Self.allCases.first(where: {
                      $0.rawValue.caseInsensitiveCompare(espnType) == .orderedSame
                  })
            else { return nil }
            self = kind
        }
    }

    /// A team the story is tagged with — ESPN's `categories` of type `team`.
    /// College programs are tagged twice (the team and the university) under
    /// one id, so tags are unique by id.
    struct TeamTag: Hashable, Sendable {
        let id: String
        let name: String
    }

    let id: String
    let kind: Kind
    let league: League
    let headline: String
    /// ESPN's `description`: the dek under the headline.
    let dek: String?
    /// Who wrote it, as the reader names them: a byline, else the wire
    /// ("AP"). Nil when ESPN names neither, and nothing is printed then.
    let attribution: String?
    let published: Date?
    /// The game the story is about, where ESPN says: the summary article's
    /// `gameId`, else an `event` category's id.
    let gameId: String?
    let teams: [TeamTag]
    /// The story's text. Nil for a feed item, whose body is fetched on open.
    var body: [StoryBlock]? = nil
    /// Where the body comes from when it didn't ride along.
    var bodyURL: URL? = nil
    /// The story's lead photo. Nil draws the row without one.
    var imageURL: URL? = nil
}

/// One block of a story's text, after the HTML is gone.
nonisolated enum StoryBlock: Hashable, Sendable {
    case heading(String)
    case paragraph(String)
}

extension NewsStory {
    /// Whether the story is about `teamId`, rather than a roundup that
    /// mentions it (N9). ESPN's `team=` filter is loose: every result is
    /// tagged with the team, but most are league-wide pieces tagged with a
    /// dozen more (Michigan's feed led with SP+ rankings for all 138 FBS
    /// teams). Two teams or fewer is one team's story or one game's.
    ///
    /// Probe, 2026-09-27: Michigan kept 6 of 25, the Knicks 11 of 25.
    func isFocused(on teamId: String) -> Bool {
        teams.count <= 2 && teams.contains { $0.id == teamId }
    }
}

extension GameSummary {
    /// The story the game page leads with, or nil: the recap once the game
    /// is final (N2), the preview before kickoff (N3), and nothing live,
    /// when the page's budget belongs to the game itself. A story filed
    /// under another game never shows — every summary sampled carries its
    /// own game's, and this keeps a payload that didn't from saying so.
    func story(forGame gameId: String, status: GameStatus) -> NewsStory? {
        guard let article, article.gameId == gameId else { return nil }
        switch (article.kind, status) {
        case (.recap, .final), (.preview, .pre): return article
        default: return nil
        }
    }
}
