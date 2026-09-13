import SwiftUI

/// The shared standings row run — rows, inset dividers, and, when the
/// season's format earns it, the championship cut line after the top two
/// with its footnote. The cut is FotMob's colored table zones translated
/// into the budget: a full-bleed hairline against the rows' inset ones,
/// decoded by text instead of swatches. ConferencePage and TeamPage's
/// Standings tab both render through here so the rule lives once.
///
/// Two layouts, chosen by whether the league's columns fit a phone
/// (`League.standingsScrollsHorizontally`). College football, basketball
/// and hockey keep two or three columns and render as whole rows. The NFL
/// keeps twelve — ESPN's own spread — so its identity column pins and the
/// numbers scroll under their captions beside it, which is what ESPN and
/// FotMob both do with a table this wide.
struct StandingsList: View {
    let entries: [ConferenceStanding]
    let highlightTeamId: String?
    /// Whether this table's top two reach a title game — the caller's
    /// knowledge (`Conference.titleGameIsTopTwo` plus its season).
    let showsTitleGameCut: Bool
    /// In-progress games to badge rows with live fortunes (Andy,
    /// 2026-08-29). Callers pass the scoreboard's live slate for the
    /// current season and nothing for past ones.
    var liveGames: [Game] = []

    /// The cut renders only when the top two are knowably the top two:
    /// seed-backed placement (ESPN's `playoffSeed` — payload order alone
    /// is not the standings), a table bigger than the pair, and a non-0-0
    /// record so preseason's carried-over order claims nothing.
    private var cutIsVisible: Bool {
        guard showsTitleGameCut, entries.count > 2,
              entries[0].playoffSeed == 1, entries[1].playoffSeed == 2,
              let record = entries.first?.conferenceRecord else { return false }
        return record != "0-0"
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How many places reach the title game. Two, in every conference
    /// format that plays one — `cutIsVisible` is what decides whether this
    /// season's format does.
    private static let championshipPlaces = 2

    private var league: League { entries.first?.team.league ?? .collegeFootball }
    private var columns: [StandingsColumn] { league.standingsColumns }

    /// The pinned-column layout, for a table wider than the screen. Not at
    /// accessibility text sizes: the rows stack their numbers onto a
    /// labeled line there, so there is nothing left to scroll.
    private var isPinned: Bool {
        league.standingsScrollsHorizontally && !dynamicTypeSize.isAccessibilitySize
    }

    /// The pinned column's width: place, mark, and enough room for a team
    /// name. Fixed rather than flexible because the two columns are laid
    /// out separately and have to agree on where the seam is.
    @ScaledMetric(relativeTo: .subheadline) private var identityWidth: CGFloat = 150
    /// Both columns frame every cell to these, which is what keeps the
    /// numbers level with the names beside them.
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var captionHeight: CGFloat = 35
    /// Mirrors the cells' own metric so the scrolling column can be given
    /// a known width — a `Divider` inside a horizontal scroll view has no
    /// width to fill unless something states one.
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    private var numbersWidth: CGFloat {
        columns.map { $0.width * scale }.reduce(0, +)
            + CGFloat(max(columns.count - 1, 0)) * Spacing.md
    }

    private func cutBar(bridgesDivider: Bool) -> some View {
        Rectangle()
            .fill(Color.textPrimary)
            .frame(width: 3)
            // Negative padding grows the overlay past the row's own bounds;
            // overlays aren't clipped, so this is what closes the seam.
            .padding(.bottom, bridgesDivider ? -1 : 0)
            .accessibilityHidden(true)
    }

    /// The legend, which is what makes the bar mean something. Same swatch,
    /// so the eye pairs them without a caption having to say "the bar".
    private var legend: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.textPrimary)
                .frame(width: 3, height: 12)
            Text("Championship game")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The top \(Self.championshipPlaces) reach the championship game")
    }

    private func liveResult(for teamId: String) -> LiveResult? {
        liveGames.lazy.compactMap { $0.liveResult(for: teamId) }.first
    }

    private func qualifies(_ index: Int) -> Bool {
        cutIsVisible && index < Self.championshipPlaces
    }

    var body: some View {
        VStack(spacing: 0) {
            if isPinned { pinnedTable } else { wholeRowTable }
            if cutIsVisible { legend }
        }
    }

    // MARK: - Whole rows

    @ViewBuilder
    private var wholeRowTable: some View {
        // At accessibility sizes the rows stack their records onto a
        // labeled line, so the captions would caption nothing.
        if !dynamicTypeSize.isAccessibilitySize {
            StandingsColumnCaptions(league: league)
        }
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, standing in
            NavigationLink(value: standing.team) {
                ConferenceStandingRow(standing: standing, position: index + 1,
                                      liveResult: liveResult(for: standing.team.id),
                                      qualifies: qualifies(index))
            }
            .buttonStyle(.plain)
            .background(standing.team.id == highlightTeamId ? Color.bgHeader : Color.clear)
            // FotMob's promotion/relegation mechanism (Andy, 2026-09-06):
            // a bar down the leading edge of every qualifying row, keyed by
            // a legend under the table. It marks *which* teams are in, where
            // the full-bleed divider it replaces could only say where the
            // line fell — and it survives a scroll that leaves the line off
            // screen. Ink, not colour: the budget stays at three, and the
            // bar is the strongest monochrome mark a row edge can carry.
            .overlay(alignment: .leading) {
                // Bridges the 1pt divider between two qualifying rows, so
                // the group reads as one continuous mark rather than a bar
                // per row — which is the difference between "these two are
                // in" and "this one is, and so is this one".
                if qualifies(index) {
                    cutBar(bridgesDivider: index < Self.championshipPlaces - 1)
                }
            }
            .id(standing.id)
            if standing.id != entries.last?.id {
                Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
            }
        }
    }

    // MARK: - Pinned identity, scrolling numbers

    /// Two columns laid out side by side: the identity one fixed at the
    /// leading edge, the numeric one inside a horizontal scroll view.
    ///
    /// Both are built from the same row list and frame every cell to the
    /// same heights, which is what keeps a name level with its numbers —
    /// there is no single row view spanning the seam to do it for them.
    private var pinnedTable: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                StandingsIdentityCaption(width: identityWidth)
                    .padding(.leading, Spacing.lg)
                    .captionCell(height: captionHeight)
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, standing in
                    NavigationLink(value: standing.team) {
                        StandingsIdentityCell(
                            standing: standing, position: index + 1,
                            liveResult: liveResult(for: standing.team.id),
                            width: identityWidth
                        )
                        .padding(.leading, Spacing.lg)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(standing.team.id == highlightTeamId ? Color.bgHeader : Color.clear)
                    .overlay(alignment: .leading) {
                        if qualifies(index) {
                            cutBar(bridgesDivider: index < Self.championshipPlaces - 1)
                        }
                    }
                    // The row's whole sentence lives here; the numbers
                    // beside it are hidden from VoiceOver so a team is one
                    // element, not two.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(StandingsSentence.spoken(
                        standing, columns: columns, position: index + 1,
                        liveResult: liveResult(for: standing.team.id),
                        qualifies: qualifies(index)))
                    .id(standing.id)
                    if standing.id != entries.last?.id {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    StandingsNumbersCaption(columns: columns)
                        .captionCell(height: captionHeight)
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, standing in
                        NavigationLink(value: standing.team) {
                            StandingsNumbersCell(standing: standing, columns: columns)
                                .frame(height: rowHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(standing.team.id == highlightTeamId ? Color.bgHeader : Color.clear)
                        .accessibilityHidden(true)
                        if standing.id != entries.last?.id {
                            Divider().overlay(Color.divider)
                        }
                    }
                }
                .frame(width: numbersWidth, alignment: .leading)
                .padding(.leading, Spacing.md)
                .padding(.trailing, Spacing.lg)
            }
        }
    }
}

private extension View {
    /// A caption cell in the pinned layout: the caption row's own look,
    /// framed to the height both columns agree on.
    func captionCell(height: CGFloat) -> some View {
        self
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            // After the padding, so this is the row's *total* height —
            // which is the number the other column has to match.
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
