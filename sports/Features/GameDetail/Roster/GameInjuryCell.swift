import SwiftUI

/// One name on the Injuries card: the player, then the status in the
/// heavier meta weight and what ESPN knows about it — "Questionable ·
/// Neck · Oct 25". Links to the player's page when ESPN sent an id.
struct GameInjuryCell: View {
    let injury: GameInjury
    let team: Team
    let league: League

    @ScaledMetric(relativeTo: .subheadline) private var discSize: CGFloat = 32

    var body: some View {
        if isLinkable {
            NavigationLink(value: identity) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            PersonDisc(jersey: injury.jersey, url: injury.thumbnailURL, size: discSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(injury.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(injury.status)
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                if let detailLine {
                    Text(detailLine)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// "Neck · Oct 25": the ailment and the return date ESPN gives, each
    /// dropping out on its own.
    private var detailLine: String? {
        let parts = [injury.position, injury.detail, injury.returnDateText()].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A synthesized id (`teamId-name`, no athlete behind it) must never
    /// become a navigation target — the box score's rule (2026-09-24).
    private var isLinkable: Bool {
        !injury.id.isEmpty && injury.id.allSatisfy(\.isNumber)
    }

    private var identity: PlayerIdentity {
        PlayerIdentity(athleteId: injury.id, name: injury.name, league: league,
                       teamName: team.displayName ?? team.location,
                       teamLogoURL: team.logoURL, team: team,
                       jersey: injury.jersey, position: injury.position,
                       headshotURL: injury.headshotURL, injuryStatus: injury.status)
    }

    private var accessibilityText: String {
        ([injury.name, injury.status] + [detailLine].compactMap { $0 }).joined(separator: ", ")
    }
}
