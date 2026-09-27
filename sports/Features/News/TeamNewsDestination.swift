import Foundation

/// A team page opened on its News tab: where a For you team section's
/// "See more" goes (2026-09-27). Its own value rather than a flag on `Team`,
/// which every other push hands over bare.
struct TeamNewsDestination: Hashable {
    let team: Team
}
