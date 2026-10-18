import SwiftUI

/// One player on the formation: the disc, and "12 Mahomes" under it.
/// A link to the player's page, like every other name in the app since
/// E20.
struct FormationSlot: View {
    let person: GameRoster.Person
    let team: Team
    let league: League

    @ScaledMetric(relativeTo: .caption2) private var discSize: CGFloat = 32

    var body: some View {
        NavigationLink(value: PlayerIdentity(person: person, team: team, league: league)) {
            VStack(spacing: 2) {
                PersonDisc(jersey: person.jersey, url: person.thumbnailURL, size: discSize)
                    // A hairline of card color so the disc stands off the
                    // surface it shares a gray with.
                    .overlay(Circle().stroke(Color.bgCard, lineWidth: 1.5))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 1)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
        .buttonStyle(.plain)
    }

    private var label: String {
        [person.jersey, person.shortName].compactMap { $0 }.joined(separator: " ")
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let jersey = person.jersey { parts.append("Number \(jersey)") }
        parts.append(person.name)
        if let position = person.positionName ?? person.position { parts.append(position) }
        return parts.joined(separator: ", ")
    }
}
