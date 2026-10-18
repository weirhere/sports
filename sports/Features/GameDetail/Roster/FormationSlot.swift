import SwiftUI

/// One player on the formation: the disc, and "12 Mahomes" under it.
/// A link to the player's page, like every other name in the app since
/// E20.
struct FormationSlot: View {
    let person: GameRoster.Person
    let team: Team
    let league: League
    /// The name's color on the surface — `textPrimary` on turf and maple,
    /// which deepen in dark mode; fixed dark ink on ice, which doesn't.
    var ink: Color = .textPrimary
    /// A ceiling for a wing, so it holds the edge rather than spreading
    /// into the field; nil shares the row evenly. A ceiling and not a
    /// fixed width because five wings (three wideouts, two tight ends)
    /// at a fixed width overflowed the field and shoved the page sideways.
    var maxWidth: CGFloat? = nil

    @ScaledMetric(relativeTo: .caption2) private var discSize: CGFloat = 32

    var body: some View {
        NavigationLink(value: PlayerIdentity(person: person, team: team, league: league)) {
            VStack(spacing: 2) {
                PersonDisc(jersey: person.jersey, url: person.thumbnailURL, size: discSize)
                    // A hairline of the surface's own ink, translucent, so
                    // the disc stands off ice it shares a gray with without
                    // a pure-white ring on turf (Andy, 2026-10-18).
                    .overlay(Circle().stroke(ink.opacity(0.35), lineWidth: 1))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: maxWidth ?? .infinity)
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
