import SwiftUI

/// One row of the tables hub's Following card, resolved against what
/// actually loaded — a followed table whose data didn't come back has no
/// row, the same way an empty league has no accordion.
struct FollowedTableRow: Identifiable {
    enum Content {
        case poll([Poll], League)
        case conference(ConferenceStandings)
    }

    let table: FollowedTable
    let content: Content

    var id: String { table.token }
}

/// The tables hub's Following card: every followed table in the order the
/// user dragged it into (Andy, 2026-09-06).
///
/// The order is the point. It is the same order the Scores screen hoists
/// these tables in, directly under Following — so arranging the list here
/// is arranging the top of the scores page, which is the only place the
/// order has to earn its keep.
///
/// Reordering is drag-and-drop rather than an edit mode: the card lives
/// inside the hub's ScrollView, and a `List` nested in a ScrollView fights
/// it for every gesture. A long press lifts a row, dropping it on another
/// takes that row's place. VoiceOver gets Move up / Move down actions,
/// because a drag is not an accessible affordance and this is the only way
/// to set the order.
struct FollowedTablesCard: View {
    let rows: [FollowedTableRow]

    @Environment(FollowingStore.self) private var following

    /// The row a drop would land on.
    @State private var target: FollowedTable?

    /// One row can't be reordered, so it shows no grips and takes no drags.
    private var isReorderable: Bool { rows.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                rowView(row)
            }
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    @ViewBuilder
    private func rowView(_ row: FollowedTableRow) -> some View {
        let table = row.table
        HStack(spacing: 0) {
            switch row.content {
            case .poll(let polls, let league):
                Top25Row(polls: polls, league: league)
            case .conference(let conference):
                ConferenceListRow(conference: conference)
            }
            if isReorderable {
                grip
            }
        }
        .background(target == table ? Color.bgElevated : Color.clear)
        .contentShape(Rectangle())
        .modifier(ReorderDrag(table: table, enabled: isReorderable, target: $target,
                              onDrop: { dropped in following.move(dropped, onto: table) }))
        .accessibilityAction(named: "Move up") { move(table, by: -1) }
        .accessibilityAction(named: "Move down") { move(table, by: 1) }
    }

    /// Trailing, where iOS puts a reorder handle — after the follow star,
    /// so the star keeps the position it has in every other list.
    private var grip: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.textSecondary)
            .padding(.trailing, Spacing.lg)
            .padding(.leading, Spacing.xs)
            .accessibilityHidden(true)
    }

    /// The VoiceOver path. Clamped rather than wrapping: "move up" from
    /// the top should do nothing, not send the row to the bottom.
    private func move(_ table: FollowedTable, by offset: Int) {
        let tables = following.orderedTables
        guard let index = tables.firstIndex(of: table) else { return }
        let destination = index + offset
        guard tables.indices.contains(destination) else { return }
        following.move(table, onto: tables[destination])
    }
}

/// The drag half, factored out so the row body stays readable and the
/// whole thing can be switched off for a one-row list.
///
/// The payload is the `FollowedTable` token, and the drop is guarded by
/// parsing it back: a text drag from anywhere else in the system lands on
/// this card too, and must be a no-op rather than a reorder.
private struct ReorderDrag: ViewModifier {
    let table: FollowedTable
    let enabled: Bool
    @Binding var target: FollowedTable?
    let onDrop: (FollowedTable) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(table.token) {
                    // The lift preview. A row-wide snapshot would drag the
                    // navigation link and the follow star with it, so the
                    // name alone stands in.
                    Text(table.name)
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                        .padding(Spacing.sm)
                        .background(Color.bgCard)
                }
                .dropDestination(for: String.self) { items, _ in
                    target = nil
                    guard let dropped = items.compactMap(FollowedTable.init(token:)).first
                    else { return false }
                    withAnimation { onDrop(dropped) }
                    return true
                } isTargeted: { isTargeted in
                    target = isTargeted ? table : nil
                }
        } else {
            content
        }
    }
}
