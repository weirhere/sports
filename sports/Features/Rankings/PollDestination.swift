import Foundation

/// The poll page as a routable value.
///
/// League-qualified for the reason the row and the hero mark are (Andy,
/// 2026-09-06): "Top 25" never says whose, which is fine while college
/// football is the only league that polls and wrong the moment a second
/// one does.
///
/// Every push is by value (2026-09-27). The tables hub used to push
/// `PollScreen` view-based, and a value push from anywhere above a
/// view-pushed screen — a team page's conference badges — lands in the
/// path *under* it, so SwiftUI rebuilt the team page in place instead of
/// opening the conference. The hub hands over the polls it already fetched;
/// Scores holds none, so the page fetches the season in progress itself.
struct PollDestination: Hashable {
    var league: League = .collegeFootball
    var polls: [Poll] = []
    /// Open on the News tab: the News page's "See more" (2026-09-27).
    var opensNews: Bool = false
}
