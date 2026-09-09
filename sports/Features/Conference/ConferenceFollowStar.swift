import SwiftUI

/// Star toggle for following a conference — FollowButton's twin, driving
/// the conference set. Filled when following; weight, not color.
struct ConferenceFollowStar: View {
    let conference: ConferenceID
    /// Spoken in the label — a list of identical "Follow conference"
    /// buttons gives VoiceOver nothing to distinguish.
    let conferenceName: String

    @Environment(FollowingStore.self) private var following

    /// The width every trailing control on the tables hub centres in.
    static let controlColumn: CGFloat = 34

    /// How far that column sits outside the row's own trailing padding
    /// (Andy, 2026-09-09: "move both the chevrons and the stars to the
    /// right by 4px"). Negative padding rather than a narrower column, so
    /// the 34pt tap target survives the nudge.
    static let controlNudge: CGFloat = -4

    var body: some View {
        Button {
            following.toggleConference(conference)
        } label: {
            Image(systemName: following.isFollowingConference(conference) ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                // Centred in the column the accordion chevrons share, so
                // the two line up down the middle rather than along their
                // right edges — a star is wider than a chevron, so edge
                // alignment left their centres apart (Andy, 2026-09-09).
                // The 34pt frame is also the tap target.
                .frame(width: Self.controlColumn, height: 34)
                .padding(.trailing, Self.controlNudge)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(following.isFollowingConference(conference)
                            ? "Unfollow \(conferenceName)" : "Follow \(conferenceName)")
        .sensoryFeedback(.impact(weight: .light),
                         trigger: following.isFollowingConference(conference))
    }
}
