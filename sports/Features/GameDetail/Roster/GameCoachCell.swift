import SwiftUI

/// One coach in the Coaches card's column: the monogram or photo disc,
/// the name, the role. The head coach links to their page (E27); the
/// coordinators from `coaches.json` have no ESPN id and don't.
struct GameCoachCell: View {
    let coach: GameCoachLine
    let team: Team
    let league: League

    @ScaledMetric(relativeTo: .subheadline) private var discSize: CGFloat = 32

    var body: some View {
        if let id = coach.coachId {
            NavigationLink(value: CoachIdentity(coachId: id, name: coach.name, league: league, team: team)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            CoachHeadshot(name: coach.name, url: coach.headshotURL, size: discSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(coach.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(coach.role)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One line of a team's staff on the game page: the head coach from the
/// roster payload, then the coordinators from `coaches.json`, in the
/// file's order.
struct GameCoachLine: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    var headshotURL: URL? = nil
    var coachId: String? = nil

    static func lines(head: RosterCoach?, staff: [StaffCoach], league: League) -> [GameCoachLine] {
        var lines: [GameCoachLine] = []
        if let head {
            lines.append(GameCoachLine(id: "head-\(head.id ?? head.name)", name: head.name,
                                       role: "Head coach", headshotURL: head.headshotURL(in: league),
                                       coachId: head.id))
        }
        for (index, member) in staff.enumerated() {
            lines.append(GameCoachLine(id: "staff-\(index)-\(member.name)", name: member.name,
                                       role: member.role))
        }
        return lines
    }
}
