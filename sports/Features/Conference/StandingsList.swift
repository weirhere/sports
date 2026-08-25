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
    // Mirror ConferenceStandingRow's column metrics so captions align
    // with the numbers beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44

    var body: some View {
        // At accessibility sizes the rows stack their records onto a
        // labeled line, so the captions would caption nothing.
        if !dynamicTypeSize.isAccessibilitySize {
            captions
        }
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, standing in
            NavigationLink(value: standing.team) {
                ConferenceStandingRow(standing: standing, position: index + 1)
            }
            .buttonStyle(.plain)
            .background(standing.team.id == highlightTeamId ? Color.bgHeader : Color.clear)
            .id(standing.id)
            if cutIsVisible, standing.id == entries[1].id {
                // Full-bleed where every other divider is inset — that
                // difference is the whole mark. Chrome, not color.
                Divider().overlay(Color.divider)
            } else if standing.id != entries.last?.id {
                Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
            }
        }
        if cutIsVisible {
            Text("Top two reach the championship game")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
        }
    }

    /// Column captions. Visual-only — each row speaks itself as a
    /// sentence, so VoiceOver skips this line.
    private var captions: some View {
        HStack(spacing: Spacing.md) {
            Text("#")
                .frame(minWidth: positionWidth, alignment: .trailing)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CONF")
                .frame(minWidth: recordWidth, alignment: .trailing)
            Text("OVR")
                .frame(minWidth: recordWidth, alignment: .trailing)
        }
        .font(.meta)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Spacing.lg)
        // Breathing room off the card header's hairline above.
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .accessibilityHidden(true)
    }
}
