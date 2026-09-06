import SwiftUI

/// The Games tab's team filter: a capsule menu of the conference's
/// members (or the poll's 25), "All teams" first. It sits beside the
/// Weeks and Date toggles and reads as their sibling — same capsule, one
/// row of controls over the cards they shape.
///
/// At rest the label is the control's name, "Team" (Andy, 2026-09-05);
/// selected, it fills and names the team, which is `ScoreFilterChip`'s
/// rule (2026-08-29): a narrowed slate is never a mystery state. The label
/// truncates rather than shoving its neighbours off the row — a long name
/// loses its tail, never the chip beside it.
struct ConferenceTeamFilterChip: View {
    let teams: [Team]
    let selection: String?
    let onSelect: (String?) -> Void

    private var selectedTeam: Team? {
        teams.first { $0.id == selection }
    }

    var body: some View {
        Menu {
            Picker("Team", selection: Binding(get: { selection }, set: onSelect)) {
                Text("All teams").tag(String?.none)
                ForEach(teams) { team in
                    Text(team.location).tag(String?.some(team.id))
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(selectedTeam?.location ?? "Team")
                    .font(.chip)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .fixedSize()
            }
            .foregroundStyle(selectedTeam == nil ? Color.textPrimary : Color.bgPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .modifier(SlateChipBackground(isActive: selectedTeam != nil))
            // Compact capsule, 44 pt tap target.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(teams.isEmpty)
        .accessibilityLabel(selectedTeam.map { "Team, \($0.location)" } ?? "Team, all teams")
        .accessibilityHint("Filters the schedule to one team")
        .accessibilityIdentifier("conference-team-filter-chip")
        .accessibilityAddTraits(selectedTeam != nil ? .isSelected : [])
    }
}

#Preview {
    let teams = [
        Team(id: "1", location: "Georgia State", name: nil, abbreviation: nil,
             displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 37),
        Team(id: "2", location: "James Madison", name: nil, abbreviation: nil,
             displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 37),
    ]
    return VStack(alignment: .leading) {
        ConferenceTeamFilterChip(teams: teams, selection: nil, onSelect: { _ in })
        ConferenceTeamFilterChip(teams: teams, selection: "1", onSelect: { _ in })
    }
    .padding()
    .background(Color.bgRecessed)
}
