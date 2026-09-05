import SwiftUI

/// Star toggle for following a conference — FollowButton's twin, driving
/// the conference set. Filled when following; weight, not color.
struct ConferenceFollowStar: View {
    let conference: ConferenceID
    /// Spoken in the label — a list of identical "Follow conference"
    /// buttons gives VoiceOver nothing to distinguish.
    let conferenceName: String

    @Environment(FollowingStore.self) private var following

    var body: some View {
        Button {
            following.toggleConference(conference)
        } label: {
            Image(systemName: following.isFollowingConference(conference) ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                // Trailing-aligned so the star's right edge sits on the same
                // trailing line as the accordion chevrons; the 34pt frame is
                // the tap target, extending inward.
                .frame(width: 34, height: 34, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(following.isFollowingConference(conference)
                            ? "Unfollow \(conferenceName)" : "Follow \(conferenceName)")
        .sensoryFeedback(.impact(weight: .light),
                         trigger: following.isFollowingConference(conference))
    }
}
