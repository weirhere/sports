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

    /// A header that names a real table splits into two surfaces (Andy's
    /// call, 2026-08-25, back with the conference stack on 2026-09-06):
    /// the mark + name push that table's page, everything after them
    /// toggles. Following, the poll and "Other" keep the whole row as the
    /// toggle — there is nowhere for their name to go.
    private var headerRow: some View {
        HStack(spacing: 0) {
            if let destination = tableDestination {
                NavigationLink(value: destination) {
                    identity
                        .padding(.leading, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Named for what the tap does, not what it says — and it
                // is the UI tests' hook for this path.
                .accessibilityLabel("\(section.title) standings")
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

    /// The page this section's name opens, where it has one. "Other" and
    /// an id the registry doesn't know deliberately get none — a page
    /// that can't name itself isn't a destination.
    private var tableDestination: ConferenceDestination? {
        guard case .conference(let id) = section.table,
              Conference.isKnown(id.id, in: id.league) else { return nil }
        return ConferenceDestination(conference: id, name: section.title)
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
                ConferenceLogo(url: section.logoURL)
            }
            Text(section.title)
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
        }
    }

    private var countAndChevron: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(section.games.count)")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
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

    /// Header glyph for the one section with no mark of its own. star.fill
    /// echoes the follow toggle on team pages, and sits in the same 18pt
    /// footprint a conference mark does, so every title starts at the same
    /// x. The poll used to take a trophy here; it wears its league's mark
    /// now (Andy, 2026-09-06), which `section.logoURL` carries.
    private var headerSymbol: String? {
        section.id == GameSection.followingId ? "star.fill" : nil
    }
}
