import SwiftUI

/// Follow toggle for a team card — a `FollowCapsule` driving the team set.
struct FollowButton: View {
    let team: Team

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowing(team)
        Button {
            following.toggle(team)
        } label: {
            FollowCapsule(isFollowing: isFollowing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Unfollow" : "Follow")
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
