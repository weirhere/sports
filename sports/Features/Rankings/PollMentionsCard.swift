import SwiftUI

/// One of the cards under a poll's Top 25 (COR-58): "Receiving votes" or
/// "Dropped out", the two lists every printed poll ends with. Both come in
/// the `/rankings` response the page already fetched. The caller hides the
/// card when its list is empty — a CFP table, or a past week built from the
/// core API, ships neither.
struct PollMentionsCard: View {
    let mentions: [PollMention]
    let kind: PollMentionRow.Kind

    var body: some View {
        VStack(spacing: 0) {
            header
            LazyVStack(spacing: 0) {
                ForEach(ordered) { mention in
                    // By value, never view-based: see PollDestination.
                    NavigationLink(value: mention.team) {
                        PollMentionRow(mention: mention, kind: kind)
                    }
                    .buttonStyle(.plain)
                    if mention.id != ordered.last?.id {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// `CardHeader`'s type and hairline on the rows' 16pt inset rather
    /// than its 12, so the title sits over the logos and the caption over
    /// the column it names — the Top 25's captions above do the same.
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(columnCaption)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            Divider().overlay(Color.divider)
        }
    }

    private var title: String {
        switch kind {
        case .votes: "Receiving votes"
        case .droppedOut: "Dropped out"
        }
    }

    /// The last column's caption, where `RankColumnCaptions` says MOV.
    private var columnCaption: String {
        switch kind {
        case .votes: "PTS"
        case .droppedOut: "PREV"
        }
    }

    /// Votes most-first; drop-outs by the rank they held, highest first.
    /// ESPN already sends them this way, but the order is the card's
    /// promise, not the payload's.
    var ordered: [PollMention] {
        switch kind {
        case .votes:
            mentions.enumerated()
                .sorted { ($0.element.points ?? 0, -$0.offset) > ($1.element.points ?? 0, -$1.offset) }
                .map(\.element)
        case .droppedOut:
            mentions.enumerated()
                .sorted { (Self.heldRank($0.element), $0.offset) < (Self.heldRank($1.element), $1.offset) }
                .map(\.element)
        }
    }

    /// ESPN's `previous: 0` means never ranked: it sorts last, not first.
    private static func heldRank(_ mention: PollMention) -> Int {
        guard let rank = mention.previousRank, rank > 0 else { return .max }
        return rank
    }
}
