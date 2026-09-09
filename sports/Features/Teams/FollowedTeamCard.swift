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

    /// "Buckeyes · CFB Big Ten". Either half can be missing — an FCS
    /// visitor carries no conference we know — and the separator goes with
    /// it.
    private var subtitle: String? {
        let parts = [team.name, groupName].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The group the team plays in, with the league in front of it (Andy,
    /// 2026-09-09: "Cleveland Cavaliers are NBA Eastern. Tampa Bay
    /// Lightning are NHL Eastern").
    ///
    /// The league is what makes the group a name rather than a word. The
    /// directory files basketball and hockey teams under their
    /// *conference*, and both leagues call theirs Eastern and Western —
    /// so a card of followed teams was two identical subtitles for teams
    /// in different sports.
    ///
    /// For the NFL the group is the division: the directory files those
    /// teams under their conference too, so the team's own `conferenceId`
    /// would only ever say AFC or NFC.
    private var groupName: String? {
        guard let group = rawGroupName else { return nil }
        let league = team.league.shortName
        return group.localizedCaseInsensitiveContains(league) ? group : "\(league) \(group)"
    }

    private var rawGroupName: String? {
        if team.league == .nfl,
           let division = Conference.division(forTeamId: team.id, in: .nfl) {
            return Conference.name(for: division, in: .nfl)
        }
        guard Conference.isKnown(team.conferenceId, in: team.league) else { return nil }
        return Conference.name(for: team.conference)
    }

    /// One sentence: "Cleveland, NBA Eastern". Internal, not private, so
    /// the label shape is unit-testable — the other rows' labels are
    /// reachable the same way.
    var spokenLabel: String {
        let name = team.displayName ?? team.location
        guard let groupName else { return name }
        return "\(name), \(groupName)"
    }
}
