import SwiftUI

/// One collapsible section of the scores list: gray-filled header,
/// hairline-divided game rows when expanded.
struct SectionAccordion: View, Equatable {
    let section: GameSection
    let isExpanded: Bool
    let onToggle: () -> Void

    /// The section and its state, not the toggle. `onToggle` is a fresh
    /// closure on every pass of `ScoresScreen`'s body, and a closure never
    /// compares equal — so every visible accordion re-ran its body on each
    /// frame of a day drag and on every other section's toggle
    /// (2026-09-24). It always toggles `section.id`, which is compared.
    static func == (lhs: SectionAccordion, rhs: SectionAccordion) -> Bool {
        lhs.isExpanded == rhs.isExpanded && lhs.section == rhs.section
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isExpanded {
                expandedRows
            }
        }
        // Collapsing rows animate out INSIDE the shrinking card —
        // unclipped they paint over the next section's header until
        // the animation settles (Andy, 2026-08-29).
        .clipped()
    }

    /// A header that names a real table splits into two surfaces (Andy's
    /// call, 2026-08-25, back with the conference stack on 2026-09-06):
    /// the mark + name push that table's page, everything after them
    /// toggles. Following and "Other" keep the whole row as the toggle —
    /// there is nowhere for their name to go.
    private var headerRow: some View {
        HStack(spacing: 0) {
            // The name is sized first and the toggle takes what's left.
            // Otherwise the toggle's Spacer bids for half the row and a long
            // title like "Mountain West - NCAAF" wraps beside empty space.
            if nameOpensATable {
                nameLink
                    .layoutPriority(1)
                toggleButton {
                    countAndChevron
                        .padding(.leading, Spacing.sm)
                        .padding(.trailing, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                }
            } else {
                toggleButton {
                    HStack(spacing: Spacing.sm) {
                        identity
                            .layoutPriority(1)
                        countAndChevron
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
            }
        }
        .background(Color.bgHeader)
    }

    /// Whether this section's name has a page to open. "Other" and an id
    /// the registry doesn't know deliberately don't — a table that can't
    /// name itself isn't a destination. The poll always does: `PollScreen`
    /// needs nothing but a league, and fetches the rest itself.
    private var nameOpensATable: Bool {
        switch section.table {
        case .some(.conference(let id)): return Conference.isKnown(id.id, in: id.league)
        case .some(.poll): return true
        case .none: return false
        }
    }

    /// The mark + name as the push. Both accessibility labels are named for
    /// what the tap does rather than what it says — and they are the UI
    /// tests' hook for this path.
    @ViewBuilder
    private var nameLink: some View {
        switch section.table {
        case .some(.conference(let id)):
            NavigationLink(value: ConferenceDestination(conference: id, name: section.title)) {
                nameLabel
            }
            .buttonStyle(SwipeSafeButtonStyle())
            .accessibilityLabel("\(section.title) standings")
        case .some(.poll(let league)):
            NavigationLink(value: PollDestination(league: league)) {
                nameLabel
            }
            .buttonStyle(SwipeSafeButtonStyle())
            .accessibilityLabel("\(section.title) rankings")
        case .none:
            EmptyView()
        }
    }

    private var nameLabel: some View {
        identity
            .padding(.leading, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
    }

    /// The mark + name. Every section carries its own — a conference's
    /// shield, the NFL's, the poll's league mark — and `ConferenceLogo` falls
    /// back to the football glyph where ESPN ships no asset, so the titles
    /// all start at the same x either way. Following keeps the star: it is
    /// a promise about you, not a competition with a logo.
    private var identity: some View {
        HStack(spacing: Spacing.sm) {
            if let symbol = headerSymbol {
                // Same footprint as ConferenceLogo so every section
                // title starts at the same x.
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 18, height: 18)
            } else {
                ConferenceLogo(url: section.logoURL,
                               league: section.league ?? .collegeFootball)
            }
            Text(titleText)
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
        }
    }

    /// The name, with its league joined on where it needs one: "SEC - NCAAF".
    /// A conference names itself, not its sport — "ACC" and "Top 25" say
    /// nothing about which football this is now that the leagues share the
    /// page (Andy, 2026-09-06). It rode the name as a smaller caption until
    /// 2026-09-25; one line of one type reads cleaner than two sizes. Same
    /// `shortName` the game rows and search results tag with, so the app has
    /// one word for a league everywhere.
    private var titleText: String {
        guard let league = tagLeague else { return section.title }
        return "\(section.title) - \(league.shortName)"
    }

    /// The league a section needs spelled out: every one that has a league
    /// but doesn't already say it. The NFL's own section is titled "NFL",
    /// and Following spans them both.
    private var tagLeague: League? {
        guard let league = section.league,
              section.title != league.shortName,
              section.title != league.displayName else { return nil }
        return league
    }

    /// The count rides the trailing edge as a badge beside the chevron
    /// (Andy, 2026-09-25): a tally of the section, not part of its name.
    private var countAndChevron: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()
            Text("\(section.games.count)")
                .font(.metaEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, 6)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Color.divider))
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }

    /// The header's spoken sentence, carrying the same league anchor the
    /// caption does — a VoiceOver swipe lands on "ACC" with no marks and no
    /// screen to read it against, so the ambiguity is worse here, not less.
    /// Spelled out rather than abbreviated — see `League.spokenName`, which
    /// is where that rule now lives so every spoken surface inherits it.
    private var headerLabel: String {
        let games = "\(section.games.count) \(section.games.count == 1 ? "game" : "games")"
        guard let league = tagLeague else { return "\(section.title), \(games)" }
        return "\(section.title), \(league.displayName), \(games)"
    }

    private func toggleButton(@ViewBuilder content: () -> some View) -> some View {
        Button(action: onToggle) {
            content()
        }
        // The header sits on the day-swipe pane too, so it takes the same
        // style as the rows: a swipe across it must not toggle the section.
        .buttonStyle(SwipeSafeButtonStyle())
        .accessibilityLabel(headerLabel)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("scores-section-\(section.id)")
    }

    private var expandedRows: some View {
        ForEach(section.games) { game in
            // Every section on the screen is one day's slate, and the day
            // strip above says which day — so the rows are kickoff time and
            // network only. VoiceOver still speaks the full date
            // (2026-08-09). Only a cross-league section tags its rows;
            // elsewhere the screen's scope already says which league
            // you're looking at.
            SectionGameRow(game: game,
                           leagueTag: section.spansLeagues ? game.home.team.league : nil)
            if game.id != section.games.last?.id {
                Divider()
                    .overlay(Color.divider)
                    .padding(.leading, Spacing.lg)
            }
        }
    }

    /// Header glyph for the one section with no mark of its own. star.fill
    /// echoes the follow toggle on team pages, and sits in the same 18pt
    /// footprint a conference mark does, so every title starts at the same
    /// x. The poll used to take a trophy here; it wears its league's mark
    /// now (Andy, 2026-09-06), which `section.logoURL` carries.
    private var headerSymbol: String? {
        section.id == GameSection.followingId ? "star.fill" : nil
    }
}
