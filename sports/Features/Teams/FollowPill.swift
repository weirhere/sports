import SwiftUI

/// The team page's follow control: an inverted capsule while following.
/// `onDark` renders it in white ink for the team-color hero.
struct FollowPill: View {
    let teamId: String
    var onDark = false

    @Environment(FollowingStore.self) private var following

    private var ink: Color { onDark ? .white : .textPrimary }
    private var inverse: Color { onDark ? .black : Color.bgPrimary }

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
            .foregroundStyle(isFollowing ? inverse : ink)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isFollowing ? ink : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(ink, lineWidth: isFollowing ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
