import SwiftUI

/// One player in a Roster tab column: disc, name, and the number,
/// position and note under it. Half a card wide, so one line each and
/// the name shrinks a little before it truncates. A link to the player's
/// page, as every name in the app is.
struct GameRosterCell: View {
    let person: GameRoster.Person
    let team: Team
    let league: League

    @ScaledMetric(relativeTo: .subheadline) private var discSize: CGFloat = 32

    var body: some View {
        NavigationLink(value: PlayerIdentity(person: person, team: team, league: league)) {
            HStack(spacing: Spacing.sm) {
                PersonDisc(jersey: person.jersey, url: person.thumbnailURL, size: discSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(person.name)
                        .font(.teamName)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
        .buttonStyle(.plain)
    }

    private var metaLine: String {
        [person.jersey.map { "#\($0)" }, person.position, person.note]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let jersey = person.jersey { parts.append("Number \(jersey)") }
        parts.append(person.name)
        if let position = person.positionName ?? person.position { parts.append(position) }
        if let note = person.note { parts.append(note) }
        return parts.joined(separator: ", ")
    }
}
