import SwiftUI

/// One player's page, pushed from a roster row.
///
/// **One tab, so no tab row.** The design settled on four — Profile, Games,
/// Stats, Career — and three of them have no confirmed data source: ESPN's
/// athlete endpoints are unprobed (E20's P0, and `scripts/probe-athlete.sh`
/// is how that gets answered). The app's own rule decides what to do about
/// that rather than a new one: an empty roster hides the Roster tab, and game
/// detail hides its whole tab row when there is no box score. Three dead tabs
/// would promise pages that don't exist, which is the same mistake the roster
/// rows avoided by not being links in the first place. The tab row appears
/// here the moment a second tab can be filled.
struct PlayerPage: View {
    let player: PlayerIdentity

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                hero
                profileCard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.bgRecessed)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The team page's hero, addressed to a person: the photo at page scale
    /// beside the name, over team · number · position.
    ///
    /// **The spoken sentence rides the name, not the whole hero.** It used
    /// to sit on this `HStack` as `accessibilityElement(children: .ignore)`,
    /// which was right while nothing in here was tappable. The team badge is
    /// a control, and ignoring children would leave it reachable by touch
    /// and absent from VoiceOver — so the title speaks the sentence and the
    /// badge speaks for itself.
    private var hero: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            headshot
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(player.name)
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityLabel(player.spokenSummary)
                metaRow
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.sm)
    }

    /// The crest, the team as a tappable badge, then whatever is left of the
    /// line. `HeaderLinkBadge` is the app's own word for this — the crumb
    /// `TeamPage` and `ConferencePage` already use to say "this name is a
    /// destination, and it ends here" — so the player hero borrows it rather
    /// than drawing a second kind of pill.
    private var metaRow: some View {
        HStack(spacing: Spacing.xs) {
            if let logo = player.teamLogoURL {
                LogoImage(url: logo)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
            if let team = player.team, let title = teamBadgeTitle {
                NavigationLink(value: team) {
                    // `.bgCard`, not the default: this hero sits on
                    // `bgRecessed`, which is what the default fills with.
                    HeaderLinkBadge(title: title, fill: .bgCard)
                }
                .buttonStyle(.plain)
                .accessibilityHint("View team page")
            }
            if !metaTail.isEmpty {
                Text(metaTail)
                    // Already inside the title's sentence; spoken twice it
                    // would read as "Wide Receiver" trailing a full stop.
                    .accessibilityHidden(true)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    /// The badge's text, and the test for whether there is a badge at all.
    /// A door that knows the team's *name* but not the team — a box score
    /// row, whenever that door opens — keeps the name in the line instead of
    /// drawing a badge that pushes nothing.
    private var teamBadgeTitle: String? {
        guard player.team != nil,
              let name = player.teamName, !name.isEmpty else { return nil }
        return name
    }

    /// What the line says beside the badge, or the whole line when there
    /// isn't one.
    private var metaTail: String {
        teamBadgeTitle == nil ? player.metaLine : player.metaLineWithoutTeam
    }

    /// The full-size press photo, which is the one place in the app it is the
    /// right asset: a roster shows a hundred of these discs and asks the CDN
    /// combiner for thumbnails, a page shows one.
    private var headshot: some View {
        LogoImage(url: player.headshotURL, placeholder: nil, contentMode: .fill)
            .frame(width: 76, height: 76)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
    }

    /// `TeamRecordCard`'s label/value pairs, so a fact about a player and the
    /// same fact about a team read in one language.
    @ViewBuilder
    private var profileCard: some View {
        let rows = player.profileRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                CardHeader(title: "Profile")
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    profileRow(label: row.label, value: row.value)
                    if index < rows.count - 1 {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
            .padding(.bottom, Spacing.xs)
            .cardSurface()
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}
