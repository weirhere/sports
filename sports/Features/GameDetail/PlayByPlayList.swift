import SwiftUI

/// The Plays tab: every possession, newest first, each one expanding into
/// its plays — ESPN's Play-by-Play and FotMob's Commentary answering the
/// same question. Newest first because the question a play list gets asked
/// is "what just happened", live or final.
///
/// Collapsed, a drive row is exactly the row the Drives card carried
/// before it moved here (2026-09-06): mark, result, "5 plays, 20 yards,
/// 2:39". The card is the app's density language, not a card per drive —
/// a full game is 22 possessions.
struct PlayByPlayList: View {
    let summary: GameSummary
    /// Scoring-only narrows every drive to the plays that put points up,
    /// and drops the drives that put none.
    let scoringOnly: Bool

    @State private var expanded: Set<String> = []
    /// The current drive opens itself once, on arrival. Kept as an id
    /// rather than a Bool so a new possession re-opens and a drive the
    /// user collapsed by hand stays collapsed.
    @State private var autoExpandedDrive: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var clockWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 16

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    /// The current drive leads, then finished possessions in reverse. A
    /// live game's newest football is at the top of the tab either way.
    private var drives: [Drive] {
        let current = summary.currentDrive
        let previous = summary.drives.reversed()
            // ESPN can ship the possession that just ended as both the
            // current drive and the newest previous one; two rows under
            // one id is a ForEach the list can't render.
            .filter { $0.id != current?.id }
            .filter { !scoringOnly || !$0.scoringPlays.isEmpty }
        guard let current else { return Array(previous) }
        // Scoring-only has nothing to say about a drive still in progress.
        return (scoringOnly && current.scoringPlays.isEmpty ? [] : [current]) + previous
    }

    var body: some View {
        // Resolved once: the list is derived, and re-deriving it per row
        // to answer "did the quarter change" is 22 passes over 22 drives.
        let list = drives
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, drive in
                if index == 0 || list[index - 1].period != drive.period {
                    Text(PeriodLabel.text(drive.period))
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, index == 0 ? Spacing.sm : Spacing.lg)
                        .padding(.bottom, Spacing.xs)
                }
                driveRow(drive)
                if isExpanded(drive) {
                    playList(drive)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.sm)
        .task(id: summary.currentDrive?.id) {
            guard let id = summary.currentDrive?.id, autoExpandedDrive != id else { return }
            autoExpandedDrive = id
            expanded.insert(id)
        }
    }

    /// Scoring-only is its own answer — every drive shown has a score in
    /// it, so they all stand open and the chevrons come off.
    private func isExpanded(_ drive: Drive) -> Bool {
        scoringOnly || expanded.contains(drive.id)
    }

    private func plays(_ drive: Drive) -> [Play] {
        scoringOnly ? drive.scoringPlays : drive.plays
    }

    // MARK: - Drive header

    @ViewBuilder
    private func driveRow(_ drive: Drive) -> some View {
        let canExpand = !scoringOnly && !drive.plays.isEmpty
        Button {
            guard canExpand else { return }
            if expanded.contains(drive.id) { expanded.remove(drive.id) } else { expanded.insert(drive.id) }
        } label: {
            HStack(spacing: Spacing.md) {
                LogoImage(url: summary.team(withId: drive.teamId)?.logoURL)
                    .frame(width: logoSize, height: logoSize)
                Text(drive.result ?? "—")
                    .font(drive.isScore ? .metaEmphasis : .meta)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Spacing.sm)
                if let line = drive.summary {
                    Text(line)
                        .font(.meta.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
                if canExpand {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                        .rotationEffect(.degrees(expanded.contains(drive.id) ? 180 : 0))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        // The Scores pane's rule: a full-width surface is wider than any
        // swipe, so `.plain` would fire on the way out of a tab swipe.
        // Named, not `.swipeSafe` — the shorthand is deliberately absent.
        .buttonStyle(SwipeSafeButtonStyle())
        // Not `.disabled`: a drive ESPN shipped no plays for isn't a
        // dimmed control, it's a row with nothing behind it. The action
        // guards itself and the trait simply doesn't claim a button.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(for: drive))
        .accessibilityAddTraits(canExpand ? .isButton : [])
        .accessibilityValue(canExpand ? (expanded.contains(drive.id) ? "expanded" : "collapsed") : "")
    }

    // MARK: - Plays

    private func playList(_ drive: Drive) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plays(drive)) { play in
                PlayRow(play: play, summary: summary,
                        // Past the drive's mark, clearing the hairline.
                        indent: Spacing.lg + logoSize + Spacing.md)
            }
        }
        // A hairline down the leading edge ties the plays to the drive
        // above them without a second card or an indent nobody can see.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)
                .padding(.leading, Spacing.lg + logoSize / 2)
        }
        .padding(.bottom, Spacing.xs)
    }

    /// One spoken sentence: "Miami, punt, 5 plays, 20 yards, 2:39".
    /// Internal, not private, so the label shape is unit-testable.
    func accessibilitySummary(for drive: Drive) -> String {
        var parts: [String] = []
        if let location = summary.team(withId: drive.teamId)?.location { parts.append(location) }
        if let result = drive.result { parts.append(result.lowercased()) }
        if let line = drive.summary { parts.append(line) }
        return parts.joined(separator: ", ")
    }

    /// The play's own sentence, which `PlayRow` owns now that two lists
    /// render it. Kept here so the label shape stays reachable from where
    /// the drive's is tested.
    func accessibilitySummary(for play: Play) -> String {
        PlayRow.accessibilitySummary(for: play, in: summary)
    }
}
