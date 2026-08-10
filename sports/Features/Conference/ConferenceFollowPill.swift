import SwiftUI

/// The conference page's follow control — FollowPill's twin, driving the
/// conference follow set instead. Kept separate: the two differ in id type
/// and store method, and the pill is smaller than a generalization.
struct ConferenceFollowPill: View {
    let conferenceId: Int

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowingConference(conferenceId)
        Button {
            following.toggleConference(conferenceId)
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
        .accessibilityLabel(isFollowing ? "Following conference" : "Follow conference")
    }
}
