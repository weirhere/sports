import SwiftUI

/// The shared standings row run — rows, inset dividers, and, when the
/// season's format earns it, the championship cut line after the top two
/// with its footnote. The cut is FotMob's colored table zones translated
/// into the budget: a full-bleed hairline against the rows' inset ones,
/// decoded by text instead of swatches. ConferencePage and TeamPage's
/// Standings tab both render through here so the rule lives once.
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

    var body: some View {
        // At accessibility sizes the rows stack their records onto a
        // labeled line, so the captions would caption nothing.
        if !dynamicTypeSize.isAccessibilitySize {
            StandingsColumnCaptions(league: entries.first?.team.league ?? .collegeFootball)
        }
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, standing in
            let qualifies = cutIsVisible && index < Self.championshipPlaces
            NavigationLink(value: standing.team) {
                ConferenceStandingRow(standing: standing, position: index + 1,
                                      liveResult: liveResult(for: standing.team.id),
                                      qualifies: qualifies)
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
                if qualifies {
                    cutBar(bridgesDivider: index < Self.championshipPlaces - 1)
                }
            }
            .id(standing.id)
            if standing.id != entries.last?.id {
                Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
            }
        }
        if cutIsVisible { legend }
    }
}
