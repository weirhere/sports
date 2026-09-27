import SwiftUI

/// Follow toggle for a league's poll row — `ConferenceFollowButton`'s
/// twin, driving the poll set. Kept separate for the same reason
/// `PollFollowPill` is: the two differ in id type and store method, and
/// the button is smaller than a generalization.
struct PollFollowButton: View {
    let league: League

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowingPoll(in: league)
        Button {
            following.togglePoll(in: league)
        } label: {
            FollowCapsule(isFollowing: isFollowing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Unfollow Top 25" : "Follow Top 25")
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
