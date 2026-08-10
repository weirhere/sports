import SwiftUI

/// A conference result on the search cover: mark + name, button-not-link
/// like every search row — the destination is the Router's business.
struct SearchConferenceRow: View {
    let conference: ConferenceTeams
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                ConferenceLogo(url: Conference.logoURL(for: conference.id))
                Text(conference.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                Text("\(conference.teams.count)")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(conference.name), \(conference.teams.count) \(conference.teams.count == 1 ? "team" : "teams")")
        }
        .buttonStyle(.plain)
    }
}
