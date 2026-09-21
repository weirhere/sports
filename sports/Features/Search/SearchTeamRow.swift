import SwiftUI

/// A team result on the search cover. A plain button, not a NavigationLink —
/// search navigates by dismissing and handing the Router a pending intent,
/// the same rails widget taps ride.
struct SearchTeamRow: View {
    let team: Team
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                // The conference under the name, where the nickname used to
                // sit beside it (Andy, 2026-09-21) — the player card's shape,
                // applied to teams. "Georgia / SEC" answers a different and
                // more useful question than "Georgia Bulldogs": the nickname
                // is decoration, the conference is where the team lives.
                VStack(alignment: .leading, spacing: 2) {
                    locationText
                    conferenceText
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            // Inside the label, like TeamFollowRow: flattening outside the
            // Button would strip its button trait from the merged element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
        }
        .buttonStyle(.plain)
    }

    /// VoiceOver keeps the disambiguation the league tag used to carry —
    /// "Miami, ACC" against "Miami, NFC East" — now that the tag is gone.
    var spokenLabel: String {
        let name = team.displayName ?? team.location
        let conference = conferenceName
        return conference.isEmpty ? name : "\(name), \(conference)"
    }

    /// Empty rather than "Other" when the conference is unknown: a row that
    /// says nothing beats one that says the wrong thing confidently.
    private var conferenceName: String {
        let name = Conference.name(for: team.conferenceId, in: team.league)
        return name == "Other" ? "" : name
    }

    @ViewBuilder
    private var conferenceText: some View {
        if !conferenceName.isEmpty {
            Text(conferenceName)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    private var locationText: some View {
        Text(team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
    }

}
