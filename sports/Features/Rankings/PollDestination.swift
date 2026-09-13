import Foundation

/// The poll page as a routable value.
///
/// League-qualified for the reason the row and the hero mark are (Andy,
/// 2026-09-06): "Top 25" never says whose, which is fine while college
/// football is the only league that polls and wrong the moment a second
/// one does.
///
/// The tables hub pushes `PollScreen` view-based, handing it the polls it
/// has already fetched. Scores holds no polls at all, so its Top 25 header
/// pushes this instead and the page fetches the season in progress itself.
struct PollDestination: Hashable {
    var league: League = .collegeFootball
}
