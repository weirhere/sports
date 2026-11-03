import SwiftUI

/// The Plays tab for a league with no drives: every period, newest first,
/// each one expanding into its plays.
///
/// The drive list's shape, one rung up. Football groups by possession
/// because a possession is a unit anyone thinks in; basketball and hockey
/// have no such unit, and the period is the one they do — which is also
/// the only grouping ESPN's flat feed carries (`period.number` on every
/// play). Collapsed by default for the same reason drives are: an NBA game
/// is ~490 plays, and a wall of them answers nothing at a glance.
struct PeriodPlayList: View {
    let summary: GameSummary
    /// Whose game — what a period is called, and whether a fifth one is a
    /// shootout.
    let league: League
    var allowsShootout: Bool = false
    /// Scoring-only narrows every period to the plays that put points up,
    /// and drops the periods that put none.
    let scoringOnly: Bool

    @State private var expanded: Set<Int> = []
    /// The newest period opens itself once, on arrival — the drive list's
    /// `autoExpandedDrive` rule. Kept as the period rather than a Bool so a
    /// new period re-opens and one the user collapsed stays collapsed.
    @State private var autoExpandedPeriod: Int?

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 16

    /// One run of plays under one heading: a period, or in baseball a
    /// half-inning (2026-11-03).
    struct Segment: Hashable {
        let period: Int?
        let half: InningHalf?

        /// The expansion key: one per period, and per half within one.
        var key: Int? {
            period.map { $0 * 4 + (half.map(Self.rank) ?? 0) }
        }

        private static func rank(_ half: InningHalf) -> Int {
            switch half {
            case .top: 0
            case .middle: 1
            case .bottom: 2
            case .end: 3
            }
        }
    }

    /// One entry per period, newest first, plays newest-last inside it —
    /// the same "what just happened" order the drive list keeps.
    ///
    /// Baseball groups by half-inning and lists each at-bat's **result**
    /// alone: ESPN's feed is pitch by pitch (~516 plays a game), and every
    /// "Ball", "Foul Ball" and "Start Batter/Pitcher" row under a result
    /// is that result's working, not a play of its own. The pitches feed
    /// the live diamond instead.
    var segments: [(segment: Segment, plays: [Play])] {
        var order: [Segment] = []
        var bySegment: [Segment: [Play]] = [:]
        for play in summary.plays {
            guard !scoringOnly || play.isScoringPlay else { continue }
            if let state = play.baseball, !state.isResult { continue }
            let segment = Segment(period: play.period, half: league.isBaseball ? play.half : nil)
            if bySegment[segment] == nil { order.append(segment) }
            bySegment[segment, default: []].append(play)
        }
        return order.reversed().map { ($0, (bySegment[$0] ?? []).reversed()) }
    }

    private func title(_ segment: Segment) -> String {
        if let half = segment.half { return PeriodLabel.halfInning(segment.period, half: half) }
        return PeriodLabel.text(segment.period, in: league, allowsShootout: allowsShootout)
    }

    var body: some View {
        let list = segments
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, entry in
                periodRow(entry.segment, count: entry.plays.count)
                if isExpanded(entry.segment.key) {
                    playList(entry.plays)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.sm)
        .task(id: list.first?.segment.key) {
            guard let newest = list.first?.segment.key, autoExpandedPeriod != newest else { return }
            autoExpandedPeriod = newest
            expanded.insert(newest)
        }
    }

    /// Scoring-only is its own answer — every period shown has a score in
    /// it, so they all stand open and the chevrons come off.
    private func isExpanded(_ period: Int?) -> Bool {
        scoringOnly || period.map(expanded.contains) == true
    }

    @ViewBuilder
    private func periodRow(_ segment: Segment, count: Int) -> some View {
        let period = segment.key
        let canExpand = !scoringOnly && period != nil && count > 0
        Button {
            guard let period, canExpand else { return }
            if expanded.contains(period) { expanded.remove(period) } else { expanded.insert(period) }
        } label: {
            HStack(spacing: Spacing.md) {
                Text(title(segment))
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Spacing.sm)
                Text(count == 1 ? "1 play" : "\(count) plays")
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                if canExpand {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                        .rotationEffect(.degrees(isExpanded(period) ? 180 : 0))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        // The Scores pane's rule: a full-width surface is wider than any
        // swipe, so `.plain` would fire on the way out of a tab swipe.
        .buttonStyle(SwipeSafeButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(segment, count: count))
        .accessibilityAddTraits(canExpand ? .isButton : [])
        .accessibilityValue(canExpand ? (isExpanded(period) ? "expanded" : "collapsed") : "")
    }

    private func playList(_ plays: [Play]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plays) { play in
                PlayRow(play: play, summary: summary,
                        indent: Spacing.lg + logoSize + Spacing.md)
            }
        }
        // A hairline down the leading edge ties the plays to the period
        // above them without a second card or an indent nobody can see.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)
                .padding(.leading, Spacing.lg + logoSize / 2)
        }
        .padding(.bottom, Spacing.xs)
    }

    /// "3rd quarter, 118 plays". Internal so the label shape is testable.
    func accessibilitySummary(_ period: Int?, count: Int) -> String {
        accessibilitySummary(Segment(period: period, half: nil), count: count)
    }

    /// "top 1st inning"-style for baseball: "top 1st, 3 plays".
    func accessibilitySummary(_ segment: Segment, count: Int) -> String {
        "\(title(segment).lowercased()), \(count == 1 ? "1 play" : "\(count) plays")"
    }
}
