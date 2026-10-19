import Foundation

/// What the Scores slate is narrowed to (Andy, 2026-10-19): the whole day,
/// the live games, or the tight ones. One menu where Live and Tight were
/// two pills — "taking up more real estate than I would prefer" — and the
/// two were already exclusive, so a three-way choice is what they were.
enum SlateFocus: String, CaseIterable, Identifiable {
    case all, live, tight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All games"
        case .live: "Live"
        case .tight: "Tight"
        }
    }

    /// The line under the title in the menu, for the one row that needs
    /// it (Andy, 2026-10-19): Tight is a coined word; All games and Live
    /// say what they are, and their lines came out the same day they went
    /// in.
    var detail: String? {
        switch self {
        case .all, .live: nil
        case .tight: "Live and close late, or an upset brewing"
        }
    }

    /// The focus the two stored filters amount to.
    init(liveOnly: Bool, tightOnly: Bool) {
        self = liveOnly ? .live : tightOnly ? .tight : .all
    }
}
