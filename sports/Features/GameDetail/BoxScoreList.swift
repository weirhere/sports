import SwiftUI

/// The per-player box score: one side at a time, a card per stat category.
/// Josh Vertucci's ask — *"that's where I get a lot of context"* — and the
/// app's first player-level table.
///
/// Columns come from the payload, never from a list here: ESPN's `passing`
/// group ships five columns during play and six once the game is final, so
/// a hardcoded schema would misalign every row mid-game.
struct BoxScoreList: View {
    let summary: GameSummary

    @State private var selectedTeamId: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var statColumnWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var avatarSize: CGFloat = 28

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    private struct Entry: Identifiable {
        let team: Team
        let box: BoxScore
        var id: String { box.teamId }
    }

    /// Away first, matching every other two-sided surface in the app.
    private var entries: [Entry] {
        [summary.away, summary.home].compactMap { side -> Entry? in
            guard let side,
                  let box = summary.boxScore.first(where: { $0.teamId == side.team.id })
            else { return nil }
            return Entry(team: side.team, box: box)
        }
    }

    private var selected: Entry? {
        entries.first { $0.id == selectedTeamId } ?? entries.first
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if entries.count > 1 { teamSwitch }
            if let selected {
                ForEach(selected.box.categories) { category in
                    categoryCard(category, team: selected.team)
                }
            }
        }
    }

    // MARK: - Team switch

    /// The header cluster's grouped-capsule language (Andy, 2026-08-29),
    /// not a second tab row — the screen's tab bar is right above this and
    /// two tab rows would read as one confused control.
    ///
    /// Text only, deliberately: `LogoImage` serves ESPN's `500-dark`
    /// artwork in dark mode, which would vanish against the white fill of
    /// the active segment.
    private var teamSwitch: some View {
        HStack(spacing: 0) {
            ForEach(entries) { entry in
                let active = entry.id == selected?.id
                Button {
                    selectedTeamId = entry.id
                } label: {
                    Text(entry.team.abbreviation ?? entry.team.location)
                        .font(.chipEmphasis)
                        .lineLimit(1)
                        .foregroundStyle(active ? Color.bgPrimary : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(active ? Color.textPrimary : Color.clear))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(entry.team.location) box score")
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.bgElevated))
    }

    // MARK: - Categories

    private func categoryCard(_ category: BoxScore.Category, team: Team) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: category.label)
            if isStacked {
                stackedPlayers(category, team: team)
            } else {
                table(category, team: team)
            }
        }
        .cardSurface()
    }

    /// A `Grid` keeps every column aligned across rows on its own; the
    /// horizontal scroll is for the wide categories — `defensive` runs
    /// seven columns and can't fit a phone at any type size.
    private func table(_ category: BoxScore.Category, team: Team) -> some View {
        ScrollView(.horizontal) {
            // Rows breathe at `md` with a face on each (Andy, 2026-10-03:
            // "more room to breathe"); `xs` packed the names too tight to
            // tell apart at a glance.
            Grid(alignment: .leading, horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.md) {
                GridRow {
                    // Empty, but it anchors the name column's width to the
                    // player rows below it.
                    Text("")
                    ForEach(category.columns, id: \.self) { column in
                        Text(column)
                            .font(.rowMeta)
                            .foregroundStyle(.textSecondary)
                            .frame(minWidth: statColumnWidth, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
                Divider()
                    .overlay(Color.divider)
                    .gridCellColumns(category.columns.count + 1)

                ForEach(category.players) { player in
                    GridRow {
                        playerLink(player, team: team)
                        if player.didNotPlay {
                            // No numbers: the reason spans where they'd be.
                            dnpCell(player)
                                .gridCellColumns(max(category.columns.count, 1))
                        } else {
                            statCells(player.stats, category: category, emphasized: false)
                        }
                    }
                }

                if !category.totals.isEmpty {
                    Divider()
                        .overlay(Color.divider)
                        .gridCellColumns(category.columns.count + 1)
                    GridRow {
                        // "Total", not "Team": ESPN's rushing group ships
                        // a literal "Team" player row for sacks and
                        // kneel-downs, and two rows named Team in one
                        // table is a puzzle, not a summary.
                        Text("Total")
                            .font(.rowName)
                            .foregroundStyle(.textSecondary)
                            // Under the names, not the avatars.
                            .padding(.leading, avatarSize + Spacing.sm)
                        statCells(category.totals, category: category, emphasized: true)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }

    /// The name as the way into the player's page (2026-09-24) — the last
    /// of E20's three doors. Only where ESPN sent a real athlete id: the
    /// synthesized `teamId-name` fallback identifies a row and nothing more.
    /// Ink carries it, as on the Leaders card, rather than a chevron that a
    /// table row has no room for.
    @ViewBuilder
    private func playerLink(_ player: BoxScore.Player, team: Team) -> some View {
        if let athleteId = player.athleteId {
            NavigationLink(value: PlayerIdentity(athleteId: athleteId,
                                                 name: player.name,
                                                 league: team.league,
                                                 teamName: team.displayName ?? team.location,
                                                 teamLogoURL: team.logoURL,
                                                 team: team,
                                                 jersey: player.jersey,
                                                 headshotURL: player.headshotURL)) {
                nameCell(player, team: team)
            }
            .buttonStyle(.plain)
            .accessibilityHint("View player page")
        } else {
            nameCell(player, team: team)
        }
    }

    private func nameCell(_ player: BoxScore.Player, team: Team) -> some View {
        HStack(spacing: Spacing.sm) {
            avatar(player, team: team)
            nameLabel(player)
        }
    }

    /// The player's face in a quiet disc, as the roster and the Leaders
    /// card draw one (Andy, 2026-10-03). ESPN's "Team" line — sacks and
    /// kneel-downs booked to nobody — has no face, so it wears the team's
    /// mark instead, uncropped inside the same disc.
    private func avatar(_ player: BoxScore.Player, team: Team) -> some View {
        ZStack {
            Circle().fill(Color.bgElevated)
            if player.isTeam {
                LogoImage(url: team.logoURL, placeholder: nil)
                    .padding(avatarSize * 0.15)
            } else {
                LogoImage(url: player.headshotURL?.headshotThumbnail ?? player.headshotURL,
                          placeholder: nil, contentMode: .fill)
                    .clipShape(Circle())
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }

    private func nameLabel(_ player: BoxScore.Player) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(player.name)
                .font(.rowName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let jersey = player.jersey {
                Text("#\(jersey)")
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Each cell speaks its own column in plain English, so a VoiceOver
    /// swipe through the row says "Yards Per Pass Attempt, 7.4" rather
    /// than "AVG, 7.4" — the grid's visual header can't carry that, and
    /// a bare abbreviation read aloud means nothing.
    private func statCells(_ values: [String], category: BoxScore.Category, emphasized: Bool) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            Text(value)
                .font((emphasized ? Font.metaEmphasis : .meta).monospacedDigit())
                .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .frame(minWidth: statColumnWidth, alignment: .trailing)
                .accessibilityLabel(category.accessibilityLabel(forColumnAt: index, value: value))
        }
    }

    /// "DNP · Coach's decision": the box score's own word for a player
    /// who dressed and sat, in the stat columns' quiet weight.
    private func dnpCell(_ player: BoxScore.Player) -> some View {
        Text(["DNP", player.didNotPlayReason].compactMap { $0 }.joined(separator: " · "))
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The visible line stays the terse header ("AVG 7.4") — the stacked
    /// layout has no room to spell "Yards Per Pass Attempt" on every row —
    /// but VoiceOver gets the plain-English label, the same as the table.
    private func statLines(_ values: [String], category: BoxScore.Category) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            let column = category.columns.indices.contains(index) ? category.columns[index] : ""
            Text("\(column) \(value)")
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .accessibilityLabel(category.accessibilityLabel(forColumnAt: index, value: value))
        }
    }

    /// Accessibility sizes can't hold a table: each player becomes a name
    /// with its stats spelled out beneath, the way `LeadersList` already
    /// gives up its side-by-side halves.
    private func stackedPlayers(_ category: BoxScore.Category, team: Team) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(category.players) { player in
                VStack(alignment: .leading, spacing: 2) {
                    playerLink(player, team: team)
                    if player.didNotPlay {
                        dnpCell(player)
                    } else {
                        statLines(player.stats, category: category)
                    }
                }
            }
            if !category.totals.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.rowName)
                        .foregroundStyle(.textSecondary)
                    statLines(category.totals, category: category)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}
