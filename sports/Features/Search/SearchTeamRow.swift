import SwiftUI

/// A team result on the search cover. A plain button, not a NavigationLink —
/// search navigates by dismissing and handing the Router a pending intent,
/// the same rails widget taps ride.
struct SearchTeamRow: View {
    let team: Team
    /// Set where the result list spans leagues. Searching "Miami" returns
    /// the Hurricanes and the Dolphins; "Cincinnati" the Bearcats and the
    /// Bengals — 12 NFL locations and 24 of its 32 nicknames have a college
    /// twin, so the tag is what makes the list answerable at a glance.
    var leagueTag: League? = nil
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                if isStacked {
                    VStack(alignment: .leading, spacing: 2) {
                        locationText
                        nicknameText
                    }
                } else {
                    locationText
                    nicknameText
                }
                Spacer(minLength: Spacing.sm)
                leagueTagText
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            // Inside the label, like TeamFollowRow: flattening outside the
            // Button would strip its button trait from the merged element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
        }
        .buttonStyle(.plain)
    }

    /// VoiceOver says it too — "Miami Dolphins, NFL" — so the list is
    /// answerable without seeing the tag.
    var spokenLabel: String {
        let name = team.displayName ?? team.location
        guard let leagueTag else { return name }
        return "\(name), \(leagueTag.shortName)"
    }

    @ViewBuilder
    private var leagueTagText: some View {
        if let leagueTag {
            Text(leagueTag.shortName)
                .font(.meta)
                .tracking(0.4)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var locationText: some View {
        Text(team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(isStacked ? 2 : 1)
    }

    @ViewBuilder
    private var nicknameText: some View {
        if let nickname = team.name {
            Text(nickname)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(isStacked ? 2 : 1)
        }
    }
}
