import SwiftUI

/// Star toggle for following a league's poll — `ConferenceFollowStar`'s
/// twin, driving the poll set. Kept separate for the same reason that one
/// is: the two differ in id type and store method, and a star is smaller
/// than a generalization.
struct PollFollowStar: View {
    let league: League

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowingPoll(in: league)
        Button {
            following.togglePoll(in: league)
        } label: {
            Image(systemName: isFollowing ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                // The conference star's frame, so the hub's rows share one
                // trailing line.
                .frame(width: ConferenceFollowStar.controlColumn, height: 34)
                .padding(.trailing, ConferenceFollowStar.controlNudge)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Unfollow Top 25" : "Follow Top 25")
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
