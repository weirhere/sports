import SwiftUI

/// The team page's follow control: an inverted capsule while following.
struct FollowPill: View {
    let teamId: String

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowing(teamId)
        Button {
            following.toggle(teamId)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isFollowing ? "star.fill" : "star")
                    .font(.system(size: 12))
                Text(isFollowing ? "Following" : "Follow")
                    .font(.chip)
            }
            .foregroundStyle(isFollowing ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isFollowing ? Color.textPrimary : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(Color.textPrimary, lineWidth: isFollowing ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
