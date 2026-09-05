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
                    categoryCard(category)
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

    private func categoryCard(_ category: BoxScore.Category) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: category.label)
            if isStacked {
                stackedPlayers(category)
            } else {
                table(category)
            }
        }
        .cardSurface()
    }

    /// A `Grid` keeps every column aligned across rows on its own; the
    /// horizontal scroll is for the wide categories — `defensive` runs
    /// seven columns and can't fit a phone at any type size.
    private func table(_ category: BoxScore.Category) -> some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.xs) {
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
                        nameCell(player)
                        statCells(player.stats, columns: category.columns, emphasized: false)
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
                        statCells(category.totals, columns: category.columns, emphasized: true)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func nameCell(_ player: BoxScore.Player) -> some View {
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

    /// Each cell speaks its own column, so a VoiceOver swipe through the
    /// row says "yards, 118" rather than a bare number — the grid's
    /// visual header can't carry that.
    private func statCells(_ values: [String], columns: [String], emphasized: Bool) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            Text(value)
                .font((emphasized ? Font.metaEmphasis : .meta).monospacedDigit())
                .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .frame(minWidth: statColumnWidth, alignment: .trailing)
                .accessibilityLabel("\(columns.indices.contains(index) ? columns[index] : ""), \(value)")
        }
    }

    private func statLines(_ columns: [String], values: [String]) -> some View {
        ForEach(Array(zip(columns, values)), id: \.0) { column, value in
            Text("\(column) \(value)")
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
    }

    /// Accessibility sizes can't hold a table: each player becomes a name
    /// with its stats spelled out beneath, the way `LeadersList` already
    /// gives up its side-by-side halves.
    private func stackedPlayers(_ category: BoxScore.Category) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(category.players) { player in
                VStack(alignment: .leading, spacing: 2) {
                    nameCell(player)
                    statLines(category.columns, values: player.stats)
                }
            }
            if !category.totals.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.rowName)
                        .foregroundStyle(.textSecondary)
                    statLines(category.columns, values: category.totals)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}
