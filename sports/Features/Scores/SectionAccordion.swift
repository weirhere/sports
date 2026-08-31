import SwiftUI

/// One collapsible section of the scores list: gray-filled header,
/// hairline-divided game rows when expanded.
struct SectionAccordion: View {
    let section: GameSection
    let isExpanded: Bool
    let onToggle: () -> Void
    /// Pushes this conference's standings page; nil for non-conference
    /// sections (and "Other"), which hides the affordance entirely.
    var onOpenStandings: (() -> Void)? = nil

    @Environment(FollowingStore.self) private var following

    /// True in the date grouping, where the day header pins to the top
    /// while its games scroll (Andy, 2026-08-25) — the header becomes a
    /// floating bar and the rows their own card. Conference mode keeps the
    /// single-card accordion.
    var pinsHeader: Bool = false

    var body: some View {
        if pinsHeader {
            // The header pins while its games scroll, but still reads as
            // the card's own top edge: top corners on the header, bottom
            // corners on the rows, zero gap between them (the owning
            // LazyVStack runs spacing 0 in date mode; the section's gap to
            // the next card is the explicit bottom padding here).
            Section {
                if isExpanded {
                    VStack(spacing: 0) { expandedRows }
                        .padding(.bottom, Spacing.xs)
                        .clipShape(rowsShape)
                        .background(
                            rowsShape.fill(Color.bgCard)
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                        )
                        .padding(.bottom, Spacing.sm)
                }
            } header: {
                headerRow
                    .clipShape(headerShape)
                    .background(
                        headerShape.fill(Color.bgCard)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    )
                    .padding(.bottom, isExpanded ? 0 : Spacing.sm)
            }
        } else {
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
    }

    /// Top of the card; the bottom squares off against the rows while
    /// expanded and rounds back when the section is just its header.
    private var headerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 10,
                               bottomLeadingRadius: isExpanded ? 0 : 10,
                               bottomTrailingRadius: isExpanded ? 0 : 10,
                               topTrailingRadius: 10,
                               style: .continuous)
    }

    private var rowsShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0,
                               bottomLeadingRadius: 10,
                               bottomTrailingRadius: 10,
                               topTrailingRadius: 0,
                               style: .continuous)
    }

    private var headerRow: some View {
            // A conference header splits into two surfaces (Andy's call,
            // 2026-08-25, superseding the whole-width-toggle promise): the
            // mark + name push the conference page, everything after them
            // toggles. Non-conference headers keep the whole row as the
            // toggle — there is nowhere for their name to go.
            HStack(spacing: 0) {
                if let onOpenStandings {
                    Button(action: onOpenStandings) {
                        identity
                            .padding(.leading, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // The retired trailing icon's label, so the standings
                    // path keeps its spoken name (and its UI-test hook).
                    .accessibilityLabel("\(section.title) standings")
                    toggleButton {
                        HStack(spacing: Spacing.sm) {
                            countAndChevron
                        }
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

    /// The mark + name — a conference header's navigation surface.
    private var identity: some View {
        HStack(spacing: Spacing.sm) {
            if section.isConference {
                ConferenceLogo(url: section.logoURL)
            } else if let symbol = headerSymbol {
                // Same footprint as ConferenceLogo so every section
                // title starts at the same x.
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 18, height: 18)
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
        // Redundant paths to the page, like GameRow's context menu +
        // custom actions. Both builders are empty for non-conference
        // sections, which suppresses the menu and the action entirely.
        .contextMenu {
            if let onOpenStandings {
                Button {
                    onOpenStandings()
                } label: {
                    Label("View \(section.title) standings",
                          systemImage: "list.number")
                }
            }
        }
        .accessibilityActions {
            if let onOpenStandings {
                Button("View \(section.title) standings",
                       action: onOpenStandings)
            }
        }
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
                        GameRow(game: game, timeOnly: isDaySection)
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
                        following.toggle(game.away.team.id)
                    }
                    .accessibilityAction(named: followActionTitle(for: game.home.team)) {
                        following.toggle(game.home.team.id)
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
            following.toggle(team.id)
        } label: {
            Label(followActionTitle(for: team),
                  systemImage: following.isFollowing(team.id) ? "star.slash" : "star")
        }
    }

    private func followActionTitle(for team: Team) -> String {
        following.isFollowing(team.id) ? "Unfollow \(team.location)" : "Follow \(team.location)"
    }

    /// Header glyph for the non-conference sections. star.fill echoes the
    /// follow toggle on team pages; trophy.fill marks the poll; day
    /// sections get a calendar so their titles x-align with Following's.
    private var headerSymbol: String? {
        switch section.id {
        case GameSection.followingId: "star.fill"
        case GameSection.top25Id: "trophy.fill"
        case let id where id.hasPrefix(GameSection.dayPrefix): "calendar"
        default: nil
        }
    }

    private var isDaySection: Bool {
        section.id.hasPrefix(GameSection.dayPrefix)
    }
}
