import SwiftUI

/// The coach page's hero: the photo (or initials) beside the name, over
/// the team as a tappable badge — `PlayerPage`'s hero, for a coach. The
/// role is a Profile row, the way a player's position is (Andy,
/// 2026-09-28): the hero says who someone is and who they work for.
struct CoachHero: View {
    let coach: CoachIdentity
    /// Nil until the career loads, and for most coaches after it: ESPN has
    /// a photo for 11 of 32 NFL, 9 of 30 NBA, 5 of 32 NHL and no college
    /// head coaches (probed 2026-09-27). So the initials are the design and
    /// the photo is the upgrade.
    let headshotURL: URL?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            CoachHeadshot(name: coach.name, url: headshotURL, size: 76)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(coach.name)
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityLabel(spokenSummary)
                metaRow
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
    }

    private var metaRow: some View {
        HStack(spacing: Spacing.xs) {
            // The app's one team name, `PlayerPage.teamBadgeTitle`'s rule.
            if let team = coach.team, !(team.displayName ?? team.location).isEmpty {
                NavigationLink(value: team) {
                    HeaderLinkBadge(title: team.displayName ?? team.location, logoURL: team.logoURL)
                }
                .buttonStyle(.plain)
                .accessibilityHint("View team page")
            }
        }
    }

    private var spokenSummary: String {
        // Name and club, what the hero draws — `PlayerIdentity.spokenSummary`.
        var parts = [coach.name]
        if let team = coach.team?.displayName { parts.append(team) }
        return parts.joined(separator: ", ")
    }
}
