import SwiftUI

/// The poll page's follow control — `ConferenceFollowPill`'s twin, driving
/// the poll set.
struct PollFollowPill: View {
    let league: League

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowingPoll(in: league)
        Button {
            following.togglePoll(in: league)
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
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
        .accessibilityLabel(isFollowing ? "Following Top 25" : "Follow Top 25")
    }
}
