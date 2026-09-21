import SwiftUI

/// A conference result on the search cover: mark + name, button-not-link
/// like every search row — the destination is the Router's business.
struct SearchConferenceRow: View {
    let conference: ConferenceTeams
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                ConferenceLogo(url: Conference.logoURL(for: conference.conference),
                               league: conference.league)
                // Two lines, like the team and player rows (Andy,
                // 2026-09-21: the one-line version left a visibly shorter
                // card in a list where every other card is the accordion's
                // height). The count moves under the name and grows a
                // noun, which is also what it needed to read as a fact
                // rather than a stray number beside a title.
                VStack(alignment: .leading, spacing: 2) {
                    Text(conference.name)
                        .font(.teamName)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    // The league, not the team count (Andy, 2026-09-21).
                    // A conference only means something inside one — "NFC
                    // West" and "Big Ten" are the same kind of row and the
                    // sport is what separates them — where the count was a
                    // number nobody came here for.
                    Text(conference.league.shortName)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(conference.name), \(conference.league.shortName)")
        }
        .buttonStyle(.plain)
    }
}
