import SwiftUI

/// One followed team, as its own card. The Teams tab is the shelf of teams
/// you follow (Andy, 2026-09-05), so a followed team gets a card of its own
/// rather than a row inside a list of everybody.
///
/// The card navigates; the star unfollows — the same split every browse row
/// in the app uses.
struct FollowedTeamCard: View {
    let team: Team

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 40

    var body: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(value: team) {
                HStack(spacing: Spacing.md) {
                    LogoImage(url: team.logoURL)
                        .frame(width: logoSize, height: logoSize)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.location)
                            .font(.teamNameEmphasis)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(2)
                        if let subtitle {
                            Text(subtitle)
                                .font(.meta)
                                .foregroundStyle(.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: Spacing.sm)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
            }
            .buttonStyle(.plain)
            FollowButton(team: team)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .cardSurface()
    }

    /// "Buckeyes · Big Ten". Either half can be missing — an FCS visitor
    /// carries no conference we know — and the separator goes with it.
    private var subtitle: String? {
        let parts = [team.name, groupName].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The group the team plays in. For the NFL that's the division: the
    /// directory files NFL teams under their conference, so reading the
    /// team's own `conferenceId` would only ever say AFC or NFC.
    private var groupName: String? {
        if team.league == .nfl,
           let division = Conference.division(forTeamId: team.id, in: .nfl) {
            return Conference.name(for: division, in: .nfl)
        }
        guard Conference.isKnown(team.conferenceId, in: team.league) else { return nil }
        return Conference.name(for: team.conference)
    }

    private var spokenLabel: String {
        let name = team.displayName ?? team.location
        guard let groupName else { return name }
        return "\(name), \(groupName)"
    }
}
