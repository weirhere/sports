import SwiftUI

/// One collapsible section of the scores list: gray-filled header,
/// hairline-divided game rows when expanded.
struct SectionAccordion: View {
    let section: GameSection
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(FollowingStore.self) private var following

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

    /// The whole row toggles. The two-surface conference header retired
    /// with the conference sections themselves on 2026-09-05 — the
    /// breakdown by conference lives on Tables now, and a league header
    /// has nowhere else to go.
    private var headerRow: some View {
            toggleButton {
                HStack(spacing: Spacing.sm) {
                    identity
                    countAndChevron
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .background(Color.bgHeader)
    }

    /// The mark + name. A league header wears its league's badge, the way
    /// the conference headers wore theirs before the day axis retired them
    /// (Andy, 2026-09-06) — both leagues have a real one, so neither reads
    /// as a missing asset. Following keeps the star instead: it is a
    /// promise about you, not a competition with a logo.
    private var identity: some View {
        HStack(spacing: Spacing.sm) {
            if let symbol = headerSymbol {
                // Same footprint as ConferenceLogo so every section
                // title starts at the same x.
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 18, height: 18)
            } else if let league = section.league {
                ConferenceLogo(url: league.logoURL)
            }
            Text(section.title)
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
        }
    }

    @ViewBuilder
    private var countAndChevron: some View {
        Text("\(section.games.count)")
            .font(.meta)
            .foregroundStyle(.textSecondary)
        Spacer()
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.textSecondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }

    private func toggleButton(@ViewBuilder content: () -> some View) -> some View {
        Button(action: onToggle) {
            content()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.title), \(section.games.count) \(section.games.count == 1 ? "game" : "games")")
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("scores-section-\(section.id)")
    }

    private var expandedRows: some View {
        Group {
            ForEach(Array(section.games.enumerated()), id: \.element.id) { index, game in
                    NavigationLink(value: game) {
                        // Every row carries its own full day line ("Sat,
                        // 8/29") — the in-section day dividers came out as
                        // noise (Andy, 2026-08-25). A day section's header
                        // still names the whole day, so its rows stay
                        // time-only.
                        // Every section on the screen is one day's slate,
                        // and the day strip above says which day — so the
                        // rows are kickoff time and network only. VoiceOver
                        // still speaks the full date (2026-08-09).
                        GameRow(game: game, timeOnly: true,
                                // Only a cross-league section tags its rows;
                                // elsewhere the screen's scope already says
                                // which league you're looking at.
                                leagueTag: section.spansLeagues
                                    ? game.home.team.league : nil)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        followMenuButton(for: game.away.team)
                        followMenuButton(for: game.home.team)
                        ShareLink(
                            item: GameShareCard(game: game, summary: nil, shareText: game.shareText),
                            message: Text(game.shareText),
                            preview: SharePreview(game.shortName ?? game.name ?? "Game")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    // The row collapses to one VO element, which swallows
                    // the menu — custom actions restore parity.
                    .accessibilityAction(named: followActionTitle(for: game.away.team)) {
                        following.toggle(game.away.team)
                    }
                    .accessibilityAction(named: followActionTitle(for: game.home.team)) {
                        following.toggle(game.home.team)
                    }
                    if game.id != section.games.last?.id {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
            }
        }
    }

    private func followMenuButton(for team: Team) -> some View {
        Button {
            following.toggle(team)
        } label: {
            Label(followActionTitle(for: team),
                  systemImage: following.isFollowing(team) ? "star.slash" : "star")
        }
    }

    private func followActionTitle(for team: Team) -> String {
        following.isFollowing(team) ? "Unfollow \(team.location)" : "Follow \(team.location)"
    }

    /// Header glyph for the sections with no mark of their own. star.fill
    /// echoes the follow toggle on team pages, and sits in the same 18pt
    /// footprint a league mark does so every title starts at the same x.
    private var headerSymbol: String? {
        section.id == GameSection.followingId ? "star.fill" : nil
    }
}
