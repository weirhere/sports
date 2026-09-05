import SwiftUI

/// Star toggle for following a team. Filled when following — weight, not color.
struct FollowButton: View {
    let team: Team

    @Environment(FollowingStore.self) private var following

    var body: some View {
        Button {
            following.toggle(team)
        } label: {
            Image(systemName: following.isFollowing(team) ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                // Trailing-aligned so the star's right edge sits on the same
                // trailing line as the accordion chevrons; the 34pt frame is
                // the tap target, extending inward.
                .frame(width: 34, height: 34, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(following.isFollowing(team) ? "Unfollow" : "Follow")
        .sensoryFeedback(.impact(weight: .light), trigger: following.isFollowing(team))
    }
}
