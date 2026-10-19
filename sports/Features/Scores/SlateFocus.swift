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

    /// The line under the title in the menu (Andy, 2026-10-19): Tight is
    /// a coined word, and one description makes the other two want theirs.
    var detail: String {
        switch self {
        case .all: "Everything on the day"
        case .live: "In progress now"
        case .tight: "Live and close late, or an upset brewing"
        }
    }

    /// The focus the two stored filters amount to.
    init(liveOnly: Bool, tightOnly: Bool) {
        self = liveOnly ? .live : tightOnly ? .tight : .all
    }
}
