import SwiftUI

/// The team page's follow control: an inverted capsule while following.
///
/// Text only. The star came out (Andy, 2026-09-05) because "Following" was
/// truncating to "F(" in the toolbar — the bar carries back, bell, pill and
/// share, and the pill is the only one the system will squeeze. The label
/// is the control's whole meaning, so the icon was what could go.
struct FollowPill: View {
    let team: Team

    @Environment(FollowingStore.self) private var following

    private var ink: Color { .textPrimary }
    private var inverse: Color { Color.bgPrimary }

    var body: some View {
        let isFollowing = following.isFollowing(team)
        Button {
            following.toggle(team)
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.chip)
                .lineLimit(1)
                // Never let the toolbar compress the word away again.
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isFollowing ? inverse : ink)
                .padding(.horizontal, Spacing.md)
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
