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
    /// What the door that opened this page knew. A roster row knows
    /// everything; a search result knows a name, a league and a club.
    let player: PlayerIdentity

    /// The same person, with whatever the athlete endpoint could add. Starts
    /// as `player` so the page paints immediately and fills in behind —
    /// there is never a spinner over facts that are already on screen.
    @Environment(TeamDirectoryStore.self) private var directory

    @State private var filled: PlayerIdentity?

    private var shown: PlayerIdentity { filled ?? player }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                hero
                profileCard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        // The entity pages' header, applied here too (Andy, 2026-09-21,
        // from the web twin): `bgCard` through the status-bar strip and the
        // top bounce, a solid card-color nav bar seamless against it, and
        // the hero sitting on that band rather than bare on the recessed
        // ground. TeamPage and ConferencePage have read this way since
        // 2026-08-31; the player page was the one entity page that didn't.
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // Only when the door left the page empty. Arriving from a roster,
        // every row is already here and the request would buy nothing —
        // the API rules say be a polite guest (Andy, 2026-09-21).
        .task {
            guard player.profileRows.isEmpty else { return }
            let (fetched, teamId) = await AthleteProfileClient().filling(player)
            var resolved = fetched
            // The badge needs a `Team`, not a name: search hands over a club
            // string with no id, so the crest chip couldn't render and the
            // club sat there as plain text (Andy, 2026-09-21). The athlete
            // payload names the team by id, and the directory — already in
            // memory, league-scoped so ids can't collide — turns it into
            // something pushable.
            if let teamId {
                resolved.team = directory.team(matching: TeamRef(id: teamId,
                                                                 league: player.league))
                resolved.teamLogoURL = resolved.teamLogoURL ?? resolved.team?.logoURL
            }
            filled = resolved
        }
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
                Text(shown.name)
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityLabel(shown.spokenSummary)
                metaRow
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Full-bleed: the band has to reach the screen edges, so the card
        // paint is pushed back out past the page's own gutter.
        .padding(.horizontal, Spacing.lg)
        .background(Color.bgCard)
        .padding(.horizontal, -Spacing.lg)
    }

    /// The crest, the team as a tappable badge, then whatever is left of the
    /// line. `HeaderLinkBadge` is the app's own word for this — the crumb
    /// `TeamPage` and `ConferencePage` already use to say "this name is a
    /// destination, and it ends here" — so the player hero borrows it rather
    /// than drawing a second kind of pill.
    private var metaRow: some View {
        HStack(spacing: Spacing.xs) {
            if let team = shown.team, let title = teamBadgeTitle {
                NavigationLink(value: team) {
                    // The default `bgRecessed` fill, same as the league and
                    // conference crumbs on TeamPage (Andy, 2026-09-21). The
                    // `.bgCard` override this carried was correct while the
                    // hero sat on recessed ground; the hero moved onto the
                    // card band earlier today and the override went stale,
                    // filling the badge with the colour behind it — the
                    // exact failure `HeaderLinkBadge`'s own comment warns
                    // about, in the other direction.
                    HeaderLinkBadge(title: title, logoURL: shown.teamLogoURL)
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
        guard shown.team != nil,
              let name = shown.teamName, !name.isEmpty else { return nil }
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
        LogoImage(url: shown.headshotURL, placeholder: nil, contentMode: .fill)
            .frame(width: 76, height: 76)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
    }

    /// `TeamRecordCard`'s label/value pairs, so a fact about a player and the
    /// same fact about a team read in one language.
    @ViewBuilder
    private var profileCard: some View {
        let rows = shown.profileRows
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
