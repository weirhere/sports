import Foundation

/// A push to the story reader. Carries the game the reader's score row is
/// for (N5) when the pushing page has one — the reader prefers the live
/// board's copy of it, and falls back to this.
///
/// `linksGame` is false where the push came from that game's own page: the
/// row there is the way back, and a link would stack the same page twice.
struct StoryDestination: Hashable {
    let story: NewsStory
    var game: Game? = nil
    var linksGame: Bool = true
}

extension NewsStory.Kind {
    /// The game page card's title, and the reader's nav title.
    var title: String {
        switch self {
        case .recap: "Recap"
        case .preview: "Preview"
        case .headline, .story: "Story"
        }
    }
}
