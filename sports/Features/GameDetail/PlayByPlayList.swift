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
    /// The drive row's three stat columns, fixed so "10 pl", "79 yd" and
    /// "5:16" line up down all 22 possessions.
    @ScaledMetric(relativeTo: .caption) private var playsColumn: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var yardsColumn: CGFloat = 40
    @ScaledMetric(relativeTo: .caption) private var timeColumn: CGFloat = 32

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
            Group {
                if isStacked {
                    // At accessibility sizes the columns can't share a
                    // line with the result, so the numbers drop beneath.
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.md) {
                            driveMark(drive)
                            driveTitle(drive)
                            Spacer(minLength: Spacing.sm)
                            chevron(drive, canExpand: canExpand)
                        }
                        if let line = spokenStats(drive) {
                            Text(line)
                                .font(.meta.monospacedDigit())
                                .foregroundStyle(.textSecondary)
                                .padding(.leading, logoSize + Spacing.md)
                        }
                    }
                } else {
                    HStack(spacing: Spacing.md) {
                        driveMark(drive)
                        driveTitle(drive)
                        Spacer(minLength: Spacing.sm)
                        driveStats(drive)
                        chevron(drive, canExpand: canExpand)
                    }
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

    private func driveMark(_ drive: Drive) -> some View {
        LogoImage(url: summary.team(withId: drive.teamId)?.logoURL)
            .frame(width: logoSize, height: logoSize)
    }

    /// The result, then the score it left if it scored: "Touchdown 7–0".
    /// The drive in progress has no result yet, so it says where things
    /// stand instead — the one-line version of the Summary tab's card.
    private func driveTitle(_ drive: Drive) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(title(for: drive))
                .font(drive.isScore || isInProgress(drive) ? .metaEmphasis : .meta)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let score = drive.runningScore {
                PlayRow.runningScore(away: score.away, home: score.home, side: score.side)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func isInProgress(_ drive: Drive) -> Bool {
        drive.id == summary.currentDrive?.id
    }

    /// Internal, not private, so the in-progress rule is unit-testable.
    func title(for drive: Drive) -> String {
        if let result = drive.result { return result }
        if isInProgress(drive), let situation = summary.situation {
            if let result = situation.result { return result }
            let now = [situation.downDistanceText, situation.possessionText].compactMap(\.self)
            if !now.isEmpty { return now.joined(separator: " · ") }
        }
        return "—"
    }

    /// Plays, yards and time in fixed columns, or ESPN's whole line where
    /// the drive didn't carry its parts (CFBD, the fixtures).
    @ViewBuilder
    private func driveStats(_ drive: Drive) -> some View {
        if drive.offensivePlays == nil, drive.yards == nil, drive.timeElapsed == nil {
            if let line = drive.summary {
                Text(line)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        } else {
            HStack(spacing: Spacing.sm) {
                statColumn(drive.offensivePlays.map { "\($0) pl" }, width: playsColumn)
                statColumn(drive.yards.map { "\($0) yd" }, width: yardsColumn)
                statColumn(drive.timeElapsed, width: timeColumn)
            }
        }
    }

    private func statColumn(_ text: String?, width: CGFloat) -> some View {
        Text(text ?? "—")
            .font(.meta.monospacedDigit())
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
    }

    /// Always laid out, invisible when there's nothing to open, so a row
    /// with no plays doesn't pull its columns out of line with the rest.
    private func chevron(_ drive: Drive, canExpand: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.textSecondary)
            .rotationEffect(.degrees(expanded.contains(drive.id) ? 180 : 0))
            .opacity(canExpand ? 1 : 0)
    }

    /// "10 plays, 79 yards, 5:16" — ESPN's line where it shipped one,
    /// built from the parts where it didn't.
    private func spokenStats(_ drive: Drive) -> String? {
        if let line = drive.summary { return line }
        let parts = [drive.offensivePlays.map { "\($0) \($0 == 1 ? "play" : "plays")" },
                     drive.yards.map { "\($0) \(abs($0) == 1 ? "yard" : "yards")" },
                     drive.timeElapsed].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
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

    /// One spoken sentence: "Miami, punt, 5 plays, 20 yards, 2:39". A
    /// scoring drive adds the score it left ("Indiana 7, Miami 0"); the
    /// drive in progress says where things stand in place of a result.
    /// Internal, not private, so the label shape is unit-testable.
    func accessibilitySummary(for drive: Drive) -> String {
        var parts: [String] = []
        if let location = summary.team(withId: drive.teamId)?.location { parts.append(location) }
        let title = title(for: drive)
        if title != "—" {
            parts.append(drive.result == nil && isInProgress(drive) && summary.situation?.result == nil
                         ? "in progress, \(title.replacingOccurrences(of: " · ", with: ", "))"
                         : title.lowercased())
        }
        if let score = drive.runningScore {
            let awayName = summary.away?.team.location ?? "Away"
            let homeName = summary.home?.team.location ?? "Home"
            parts.append("\(awayName) \(score.away), \(homeName) \(score.home)")
        }
        if let line = spokenStats(drive) { parts.append(line) }
        return parts.joined(separator: ", ")
    }

    /// The play's own sentence, which `PlayRow` owns now that two lists
    /// render it. Kept here so the label shape stays reachable from where
    /// the drive's is tested.
    func accessibilitySummary(for play: Play) -> String {
        PlayRow.accessibilitySummary(for: play, in: summary)
    }
}
