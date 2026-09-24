import SwiftUI

/// One player's page: Profile, Games, Stats and Career (E20's design,
/// 2026-09-20).
///
/// **The tab row appears when there is a second tab to fill** — the rule
/// this page shipped under (2026-09-20), when it was Profile alone because
/// ESPN's athlete endpoints were unprobed. The probe ran 2026-09-24 and
/// answered from `site.web.api.espn.com` in all four leagues (see
/// `PlayerStatsClient`), so a player with a stats line gets all four tabs.
/// A player ESPN has no numbers for — a walk-on, a practice-squad name —
/// still gets Profile alone, with no row of dead tabs over it.
struct PlayerPage: View {
    /// What the door that opened this page knew. A roster row knows
    /// everything; a search result knows a name, a league and a club.
    let player: PlayerIdentity

    enum Tab: Int, CaseIterable, HeroTabItem {
        case profile, games, stats, career

        var title: String {
            switch self {
            case .profile: "Profile"
            case .games: "Games"
            case .stats: "Stats"
            case .career: "Career"
            }
        }
    }

    /// The same person, with whatever the athlete endpoint could add. Starts
    /// as `player` so the page paints immediately and fills in behind —
    /// there is never a spinner over facts that are already on screen.
    @Environment(TeamDirectoryStore.self) private var directory

    @State private var filled: PlayerIdentity?
    @State private var model: PlayerStatsModel
    @State private var tab: Tab = .profile
    /// ESPN's season year the Games tab shows; nil until one is picked,
    /// which asks ESPN for its current one.
    @State private var logSeason: Int?

    init(player: PlayerIdentity) {
        self.player = player
        _model = State(initialValue: PlayerStatsModel(athleteId: player.athleteId,
                                                      league: player.league))
    }

    private var shown: PlayerIdentity { filled ?? player }

    private var availableTabs: [Tab] {
        guard let stats = model.stats, !stats.categories.isEmpty else { return [.profile] }
        return Tab.allCases
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    hero
                    if availableTabs.count > 1 {
                        HeroTabBar(tabs: availableTabs, selection: tab,
                                   onSelect: { tab = $0 })
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgCard)

                VStack(spacing: Spacing.sm) {
                    tabContent
                }
                .padding(Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
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
        // Only when the door left the body facts out. Arriving from a
        // roster, every row is already here and the request would buy
        // nothing — the API rules say be a polite guest (Andy, 2026-09-21).
        // Keyed on height and position rather than on an empty card since
        // the box score door opened (2026-09-24): it brings a jersey, so
        // its card was never empty, and the page stopped at one row.
        .task {
            guard player.height == nil || player.position == nil else { return }
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
        // The numbers: one request, which fills the Current season card
        // and decides whether the other three tabs exist at all.
        .task { await model.loadStats() }
        // The game log waits for the Games tab — most visits never open it.
        .task(id: tab == .games ? logSeason ?? -1 : nil) {
            guard tab == .games else { return }
            await model.loadLog(season: logSeason)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch availableTabs.contains(tab) ? tab : .profile {
        case .profile:
            if let card = currentSeason { card }
            profileCard
        case .games:
            gamesPane
        case .stats:
            if let stats = model.stats { PlayerStatsPane(stats: stats) }
        case .career:
            if let stats = model.stats { PlayerCareerPane(stats: stats, league: player.league) }
        }
    }

    /// Only for the season "now" belongs to — see `CurrentSeasonCard`.
    private var currentSeason: CurrentSeasonCard? {
        guard let stats = model.stats else { return nil }
        let year = model.currentESPNSeason
        let headlines = stats.headlines(forSeason: year)
        guard !headlines.isEmpty,
              let label = stats.categories.first?.lines(for: year).last?.label else { return nil }
        return CurrentSeasonCard(seasonLabel: label, headlines: headlines)
    }

    @ViewBuilder
    private var gamesPane: some View {
        let log = model.logs[logSeason]
        if let log {
            if let chip = seasonChip(log) {
                HStack { chip; Spacer() }
            }
            if log.isEmpty {
                Text("No games this season")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                    .padding(.vertical, Spacing.xl)
            } else {
                PlayerGamesList(log: log, league: player.league,
                                category: model.stats?.categories.first?.id)
            }
        } else {
            ProgressView().padding(.vertical, Spacing.xl)
        }
    }

    /// The season menu, from ESPN's own list of seasons it will answer for.
    /// `SeasonMenuChip` speaks the app's season years; ESPN's log speaks its
    /// own (the ending year, for the NBA and NHL), so the chip converts both
    /// ways at the edge.
    private func seasonChip(_ log: PlayerGameLog) -> SeasonMenuChip? {
        guard let current = log.season, log.availableSeasons.count > 1 else { return nil }
        let league = player.league
        return SeasonMenuChip(current: league.seasonYear(fromESPN: current),
                              seasons: log.availableSeasons.map(league.seasonYear(fromESPN:)),
                              league: league) { year in
            logSeason = league.espnSeason(for: year)
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
        // Tighter under the hero once a tab row follows it — the row brings
        // its own 14pt of padding, as on TeamPage.
        .padding(.bottom, availableTabs.count > 1 ? Spacing.xs : Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The card band is the container's now (2026-09-24), shared with the
        // tab row beneath, so the hero only keeps the page gutter.
        .padding(.horizontal, Spacing.lg)
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
            if let name = unlinkedTeamName {
                Text(name)
                    // Already inside the title's sentence; spoken twice it
                    // would read as the club trailing a full stop.
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
    ///
    /// Read off the resolved `Team`, not off the door's `teamName`
    /// (2026-09-21). The two doors carry different strings for the same
    /// club — a roster row hands over `shortDisplayName ?? location`,
    /// ESPN's search index hands over its own subtitle — so one player read
    /// "Los Angeles" arriving from the roster and "Los Angeles Rams"
    /// arriving from search. `displayName ?? location` is the app's one
    /// team name, the form every other team row already uses.
    private var teamBadgeTitle: String? {
        guard let team = shown.team else { return nil }
        let name = team.displayName ?? team.location
        return name.isEmpty ? nil : name
    }

    /// The club as plain text, for the case where there is no pushable
    /// `Team` behind it — the moment before search's athlete fetch resolves
    /// one, and any future door that knows a club's name and not its id.
    ///
    /// **The number and the position used to trail this line** (Andy,
    /// 2026-09-21). They are Profile rows, and printing them in the hero as
    /// well meant the same two facts appeared twice on a page with one
    /// card on it — while reading differently by door, since the hero took
    /// them from whatever the door happened to carry. The hero says who
    /// someone is and who they play for; the card holds the facts.
    private var unlinkedTeamName: String? {
        guard teamBadgeTitle == nil,
              let name = shown.teamName, !name.isEmpty else { return nil }
        return name
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
            LabeledValueCard(title: "Profile",
                             rows: rows.map { LabeledValueCard.Row(label: $0.label, value: $0.value) })
        }
    }
}
