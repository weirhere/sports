import SwiftUI

/// An athlete in the search list (Andy, 2026-09-21).
///
/// Built on `SearchTeamRow`'s shape rather than its code: same logo size,
/// same spacing, same league tag in the trailing slot, so the Players
/// section reads as a peer of Teams rather than a different kind of list.
/// It isn't the same component because the middle differs — a team is a
/// location and a nickname, a player is a name and the club they play for,
/// and collapsing both into one row would mean a parameter that means
/// something different on each side.
///
/// The league tag is not optional here, where `SearchTeamRow` makes it a
/// choice. ESPN's search spans every sport it covers, so a name can return
/// people from several of our four leagues at once, and the tag is the only
/// thing on the row that says which page a tap opens.
struct SearchPlayerRow: View {
    let player: PlayerIdentity
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 26

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                headshot
                // The club sits *under* the name, not beside it (Andy,
                // 2026-09-21). A person and their team are one fact read
                // top-down; side by side they compete for the same line and
                // the longer of the two decides where the eye goes.
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    teamText
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search-player-\(player.id)")
    }

    /// A headshot is a photograph, not a mark, so it clips to a circle the
    /// way a person's picture does everywhere else on the phone. The
    /// fallback is the app's monochrome silhouette rather than an empty
    /// disc — plenty of athletes have no portrait on file, and a blank
    /// circle reads as a failed load.
    private var headshot: some View {
        AsyncImage(url: player.headshotURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.textSecondary.opacity(0.35))
        }
        .frame(width: headshotSize, height: headshotSize)
        .clipShape(Circle())
    }

    private var nameText: some View {
        Text(player.name)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var teamText: some View {
        if let teamName = player.teamName, !teamName.isEmpty {
            Text(teamName)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }
}
