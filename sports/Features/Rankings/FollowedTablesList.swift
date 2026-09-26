import SwiftUI

/// One row of the tables hub's Following list, resolved against what
/// actually loaded — a followed table whose data didn't come back has no
/// card, the same way an empty league has no accordion.
struct FollowedTableRow: Identifiable {
    enum Content {
        case poll([Poll], League)
        case conference(ConferenceStandings)
    }

    let table: FollowedTable
    let content: Content

    var id: String { table.token }
}

/// The tables hub's Following section: every followed table as its own
/// card, in the order the user dragged it into (Andy, 2026-09-06).
///
/// One card each rather than one card of rows (Andy, 2026-09-06), matching
/// the Teams tab: both tabs answer "the handful of things that are mine",
/// and a followed table is a destination in its own right, not an entry in
/// a list of everybody. The complete lists — where a row *is* one of many —
/// stay grouped inside their league's accordion below.
///
/// The order is the point. It is the same order the Scores screen hoists
/// these tables in, directly under Following — so arranging the list here
/// is arranging the top of the scores page, which is the only place the
/// order has to earn its keep.
///
/// ## Edit mode
///
/// Arranging and unfollowing live behind an Edit link on the section's
/// heading, which reads Done while it's on (Andy, 2026-09-25, from FotMob's
/// Leagues tab). Outside it a card is only its row: no star, no grip, no
/// gesture of any kind, so the hub scrolls over these cards exactly as it
/// scrolls over the list below them. In it, each card gains a leading
/// dismiss button and a trailing grip, and stops navigating.
///
/// That replaces a hold-to-lift on every card (2026-09-07), which two rounds
/// of tuning never made polite. Scrolling a long Following list kept
/// picking cards up, and a lift the scroll view then claimed could leave the
/// hub unable to scroll at all. A timing threshold can only guess which
/// touches mean to reorder; a mode is the user saying so.
///
/// ## The drag
///
/// The grip lifts its card the moment it's touched, like a `List`'s reorder
/// control — being in edit mode is the intent a hold used to have to infer.
/// The card then tracks the finger one-to-one while the rest of the stack
/// parts around it, and settles into the gap on release. The card body
/// takes no gesture even in edit mode, so the hub still scrolls from it.
///
/// This is a hand-rolled gesture rather than `.draggable`/`.dropDestination`
/// (Andy, 2026-09-07). The system drag session is built for carrying an
/// item *out* of a list: it detaches a small preview from the finger,
/// badges it with a green insert plus, leaves the source card sitting in
/// place, and moves nothing until the drop lands. That reads as exporting
/// a chip. A reorder should read as moving the card, so the card is what
/// moves.
///
/// It is also not a `List` in edit mode: these cards live inside the hub's
/// ScrollView, and a nested `List` fights it for every gesture. The
/// ScrollView is what the drag has to be polite about instead — the hub
/// stops scrolling for as long as a card is lifted, which is why there is
/// no auto-scroll at the edges.
///
/// VoiceOver gets Move up, Move down and Unfollow actions in either mode,
/// because a drag is not an accessible affordance and the star is gone.
struct FollowedTablesList: View {
    let rows: [FollowedTableRow]
    /// Edit mode, owned by the hub's heading link.
    let isEditing: Bool

    /// True for as long as a card is lifted. The hub reads it to stand its
    /// ScrollView down: the drag and the scroll both want vertical pans,
    /// and the drag has already earned the finger by the time this flips.
    @Binding var isReordering: Bool

    @Environment(FollowingStore.self) private var following
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The lifted card, and where it would land right now.
    @State private var lift: Lift?
    /// How far the finger has moved since the lift. Kept apart from `lift`
    /// so it can be set in its own un-animated transaction: the card has
    /// to track the finger exactly, while its neighbours spring aside.
    @State private var translation: CGFloat = 0
    /// Measured card heights, keyed by follow token. The cards are near
    /// enough the same height, but a poll teaser or an accessibility text
    /// size can stretch one, and a drag that assumed a uniform row would
    /// drift a little further out of step with every card it passed.
    @State private var heights: [String: CGFloat] = [:]
    /// Whether the grip still has a finger. `onEnded` only fires when a
    /// gesture *finishes*. One the system cancels after the lift (the
    /// scroll view claiming the touch, an interruption) never calls it,
    /// which left a card lifted and the hub unable to scroll (found
    /// 2026-09-24). `@GestureState` resets on cancellation too, so its
    /// falling edge is the drop that always happens.
    @GestureState private var gripGestureActive = false

    /// `destination` is an insertion index into the list with the lifted
    /// card taken out of it — the same index `FollowingStore.move(_:to:)`
    /// takes, so what the screen shows and what gets persisted are the one
    /// number.
    private struct Lift {
        let table: FollowedTable
        var destination: Int
    }

    /// One card can't be reordered, so it shows no grip even in edit mode.
    private var isReorderable: Bool { isEditing && rows.count > 1 }

    /// An explicit VStack, not a bare ForEach: the cards are their own
    /// stack now, and this is what puts the hub's own card rhythm between
    /// them rather than leaving the spacing to the parent's layout of one
    /// opaque child.
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(rows) { row in
                card(row)
            }
        }
        // The lift is the one moment the gesture has to announce itself:
        // the card leaves the stack and the finger owns it from here. The
        // drop needs no tap of its own — the card visibly lands.
        .sensoryFeedback(.impact(weight: .medium), trigger: lift?.table) { old, new in
            old == nil && new != nil
        }
        // A gesture that ends normally always calls `drop()`; one killed
        // out from under us — a tab switch mid-drag — never does, and a
        // lift nobody can see would leave the hub unable to scroll.
        .onDisappear {
            lift = nil
            translation = 0
            isReordering = false
        }
        .onChange(of: gripGestureActive) { _, active in
            if !active { drop() }
        }
        // Done, or the hub ending edit mode, mid-drag still lands the card.
        .onChange(of: isEditing) { _, editing in
            if !editing { drop() }
        }
    }

    @ViewBuilder
    private func card(_ row: FollowedTableRow) -> some View {
        let table = row.table
        let isLifted = lift?.table == table
        let travel: CGFloat = isLifted ? translation : shift(for: table)
        HStack(spacing: 0) {
            if isEditing {
                dismiss(table)
                    .transition(controlTransition(edge: .leading))
            }
            content(row)
                // In edit mode a card is something being arranged, not a
                // link (FotMob's behaviour): a tap aimed at the dismiss
                // button or the grip that lands a few points off shouldn't
                // push a page.
                .allowsHitTesting(!isEditing)
            if isReorderable {
                grip(for: table)
                    .transition(controlTransition(edge: .trailing))
            }
        }
        // The rows carry a list row's 7pt; a card wants a card's height.
        .padding(.vertical, Spacing.xs)
        // Applied under `cardSurface`, which clips before it fills, so the
        // lift's lighter fill follows the card's rounded corners. It is
        // also dark mode's whole lift signal: the shadow below only
        // registers in light mode, the same way the card's own does.
        .background(isLifted ? Color.bgElevated : Color.clear)
        .contentShape(Rectangle())
        .cardSurface()
        // Measured before the transforms, which don't change layout size.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            heights[table.token] = height
        }
        .shadow(color: .black.opacity(isLifted ? 0.18 : 0), radius: 14, y: 6)
        .scaleEffect(isLifted && !reduceMotion ? 1.03 : 1)
        .offset(y: travel)
        .zIndex(isLifted ? 1 : 0)
        .accessibilityAction(named: "Move up") { move(table, by: -1) }
        .accessibilityAction(named: "Move down") { move(table, by: 1) }
        .accessibilityAction(named: "Unfollow") { unfollow(table) }
    }

    /// Slides in from the card's own edge; Reduce Motion gets the fade alone.
    private func controlTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    @ViewBuilder
    private func content(_ row: FollowedTableRow) -> some View {
        switch row.content {
        // No star (Andy, 2026-09-25): unfollowing a card is edit mode's
        // dismiss button, and the same table keeps its star in its league's
        // accordion below.
        case .poll(let polls, let league):
            Top25Row(polls: polls, league: league, showsFollow: false,
                     showsLeagueTag: true)
        case .conference(let conference):
            // No leader, no record (Andy, 2026-09-21). The hub answers
            // "which league", and a name plus a standing was two answers
            // to two questions in one row.
            // The league joins the name, "SEC - NCAAF", as on the Scores
            // headers (Andy, 2026-09-25): this list mixes every league, and
            // "Eastern" is two different tables.
            ConferenceListRow(conference: conference, showsLeader: false,
                              showsFollow: false, showsLeagueTag: true)
        }
    }

    /// Leading, where iOS puts a list's delete control in edit mode. Gray,
    /// not red: the app's one red is the live accent, and a removal that
    /// one star below undoes doesn't need an alarm.
    private func dismiss(_ table: FollowedTable) -> some View {
        Button {
            unfollow(table)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, Spacing.xs)
        // The glyph is 18pt in a 44pt target, so 13pt of target sits past
        // its trailing edge, and the row after it opens with its own 16pt
        // inset. Pull both back so the glyph sits the row's own mark-to-name
        // gap from the logo (Andy, 2026-09-25: the first cut left ~21pt).
        // The overlap is safe: the row stops hit-testing in edit mode.
        .padding(.trailing, Spacing.md - Self.dismissTargetOverhang - Spacing.lg)
        // The same overhang, vertically: the 44pt target is taller than the
        // row, and counting it in layout grew every card ~5pt on Edit
        // (Andy, 2026-09-25). Only the controls should appear; the cards
        // keep their height. The target still hit-tests at full size.
        .padding(.vertical, -Self.dismissTargetOverhang)
        .accessibilityLabel("Unfollow \(table.name)")
        .accessibilityIdentifier("following-dismiss")
    }

    /// Half of the dismiss target's width the 18pt glyph doesn't fill.
    private static let dismissTargetOverhang: CGFloat = (44 - 18) / 2

    /// Trailing, where iOS puts a reorder handle. The only thing on a card
    /// that drags, and only in edit mode.
    private func grip(for table: FollowedTable) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.textSecondary)
            .padding(.trailing, Spacing.lg)
            .padding(.leading, Spacing.xs)
            // A grip is worth grabbing at only if it can be hit; the ink
            // stays 12pt.
            .contentShape(Rectangle())
            .gesture(gripDrag(table))
            .accessibilityHidden(true)
    }

    // MARK: - Gestures

    /// Lifts on touch-down: edit mode already said this is a reorder, so
    /// there is no hold to wait out. The card body keeps no gesture, so a
    /// scroll that starts anywhere but here is a scroll.
    private func gripDrag(_ table: FollowedTable) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($gripGestureActive) { _, active, _ in active = true }
            .onChanged { drag in
                beginLift(of: table)
                track(drag.translation.height)
            }
            .onEnded { _ in drop() }
    }

    /// Idempotent: the grip calls it on every change, and the first one
    /// through does the work.
    private func beginLift(of table: FollowedTable) {
        guard lift == nil, isReorderable,
              let index = rows.firstIndex(where: { $0.table == table }) else { return }
        translation = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            lift = Lift(table: table, destination: index)
        }
        isReordering = true
    }

    /// Two transactions on purpose. The card's offset is set flat, so it
    /// sits under the finger rather than chasing it; the destination — and
    /// with it every other card's shift — springs.
    private func track(_ amount: CGFloat) {
        guard let current = lift else { return }
        translation = amount
        let destination = insertionIndex(for: current.table, translation: amount)
        guard destination != current.destination else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            lift?.destination = destination
        }
    }

    /// The commit and the landing are one animation: the store reorders
    /// the cards while the lifted one's offset goes to zero, so it springs
    /// from wherever the finger left it into the gap the others are
    /// already holding open.
    private func drop() {
        guard let current = lift else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            // Resolved against the cards on screen, which skip a followed
            // table with nothing loaded — as a raw index into the full
            // order it lands a slot off.
            following.move(current.table, to: current.destination,
                           among: rows.map(\.table))
            lift = nil
            translation = 0
        }
        isReordering = false
    }

    // MARK: - Geometry

    /// Where the lifted card would land: the insertion slot whose top sits
    /// nearest the card's own top. Comparing tops rather than centers is
    /// the same comparison — both slots and card share the lifted card's
    /// height — and it means a card swaps places once it has covered half
    /// of its neighbour, which is where iOS's own reorder swaps.
    private func insertionIndex(for table: FollowedTable, translation: CGFloat) -> Int {
        guard let from = rows.firstIndex(where: { $0.table == table }) else { return 0 }
        let liftedTop = top(of: from) + translation

        // The slots the card could drop into, measured on the list with
        // the card itself removed — including the one past the last card.
        var slots: [CGFloat] = []
        var y: CGFloat = 0
        for row in rows where row.table != table {
            slots.append(y)
            y += height(of: row.table) + Spacing.sm
        }
        slots.append(y)

        var best = from
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, slot) in slots.enumerated() {
            let distance = abs(slot - liftedTop)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// How far a card that isn't the lifted one has moved aside. The
    /// lifted card keeps its own slot in the layout the whole time — that
    /// reserved slot is the gap — so opening a space is a matter of the
    /// cards between here and there stepping over it.
    private func shift(for table: FollowedTable) -> CGFloat {
        guard let current = lift,
              let from = rows.firstIndex(where: { $0.table == current.table }),
              let index = rows.firstIndex(where: { $0.table == table }),
              index != from else { return 0 }
        let step = height(of: current.table) + Spacing.sm
        let to = current.destination
        if to > from, index > from, index <= to { return -step }
        if to < from, index >= to, index < from { return step }
        return 0
    }

    private func top(of index: Int) -> CGFloat {
        rows.prefix(index).reduce(0) { $0 + height(of: $1.table) + Spacing.sm }
    }

    /// The fallback is only ever reached on the frame before a card has
    /// measured itself, which is well before anyone can press one.
    private func height(of table: FollowedTable) -> CGFloat {
        heights[table.token] ?? 52
    }

    // MARK: - Unfollow

    private func unfollow(_ table: FollowedTable) {
        withAnimation(.snappy(duration: 0.25)) {
            switch table {
            case .poll(let league): following.togglePoll(in: league)
            case .conference(let id): following.toggleConference(id)
            }
        }
    }

    // MARK: - VoiceOver

    /// The VoiceOver path. Clamped rather than wrapping: "move up" from
    /// the top should do nothing, not send the card to the bottom.
    private func move(_ table: FollowedTable, by offset: Int) {
        let tables = following.orderedTables
        guard let index = tables.firstIndex(of: table) else { return }
        let destination = index + offset
        guard tables.indices.contains(destination) else { return }
        following.move(table, onto: tables[destination])
    }
}
