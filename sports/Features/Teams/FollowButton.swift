import SwiftUI

/// Star toggle for following a team. Filled when following — weight, not color.
struct FollowButton: View {
    let teamId: String

    @Environment(FollowingStore.self) private var following

    var body: some View {
        Button {
            following.toggle(teamId)
        } label: {
            Image(systemName: following.isFollowing(teamId) ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(following.isFollowing(teamId) ? "Unfollow" : "Follow")
    }
}
