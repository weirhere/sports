import SwiftUI

/// Follow toggle for a conference row on the tables hub — a `FollowCapsule`
/// driving the conference set. The conference page's own control is
/// `ConferenceFollowPill`.
struct ConferenceFollowButton: View {
    let conference: ConferenceID
    /// Spoken in the label — a list of identical "Follow conference"
    /// buttons gives VoiceOver nothing to distinguish.
    let conferenceName: String

    @Environment(FollowingStore.self) private var following

    var body: some View {
        let isFollowing = following.isFollowingConference(conference)
        Button {
            following.toggleConference(conference)
        } label: {
            FollowCapsule(isFollowing: isFollowing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing
                            ? "Unfollow \(conferenceName)" : "Follow \(conferenceName)")
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
