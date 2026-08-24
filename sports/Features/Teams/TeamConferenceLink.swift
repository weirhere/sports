import SwiftUI

/// The team header's conference affordance: conference mark + the season's
/// standing when one exists ("1st in SEC" already names the conference) or
/// the bare conference name otherwise — so the conference stays reachable
/// offseason, on past seasons, and from entry paths that pushed no id.
/// An unknown/"Other" conference renders the standing as plain text, or
/// nothing (there is no page for Other).
struct TeamConferenceLink: View {
    let conferenceId: Int?
    let standing: String?   // caller pre-filters the 0-0 rule

    var body: some View {
        if let conferenceId, Conference.tier(for: conferenceId) != .other {
            NavigationLink(value: ConferenceDestination(
                conferenceId: conferenceId,
                name: Conference.name(for: conferenceId)
            )) {
                HStack(spacing: Spacing.xs) {
                    ConferenceLogo(url: Conference.logoURL(for: conferenceId))
                        .accessibilityHidden(true)
                    Text(standing ?? Conference.name(for: conferenceId))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.meta)
                .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("View conference standings")
        } else if let standing {
            Text(standing)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
    }
}
