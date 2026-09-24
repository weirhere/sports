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
/// ## The drag
///
/// A deliberate hold lifts a card: half a second anywhere on it, or a
/// shorter one on the grip. The card then tracks the finger one-to-one while
/// the rest of the stack parts around it, and settles into the gap on
/// release.
///
/// **Both paths wait for a still finger** (Andy, 2026-09-24: scrolling the
/// hub kept picking cards up). The lift used to come after a 0.25s hold that
/// tolerated 12pt of drift, and the grip lifted with no hold at all once the
/// finger moved 3pt. The grip's hit area is the card's whole trailing strip,
/// right where a right thumb scrolls, so a flick that happened to start
/// there or a scroll that started a little slowly became a reorder. Now a
/// lift needs a hold that stays within a few points. The finger that
/// scrolls is moving from the first frame, and the finger that means to
/// reorder settles first, which is how iOS's own lift tells them apart.
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
/// no auto-scroll at the edges. The followed set is a handful of tables,
/// so the list fits on screen.
///
/// VoiceOver gets Move up / Move down actions, because a drag is not an
/// accessible affordance and this is the only way to set the order.
struct FollowedTablesList: View {
    let rows: [FollowedTableRow]

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
    /// Whether either lift gesture still has a finger. `onEnded` only fires
    /// when a gesture *finishes*. One the system cancels after the lift (the
    /// scroll view claiming the touch, an interruption) never calls it,
    /// which left a card lifted and the hub unable to scroll (found
    /// 2026-09-24). `@GestureState` resets on cancellation too, so its
    /// falling edge is the drop that always happens.
    @GestureState private var cardGestureActive = false
    @GestureState private var gripGestureActive = false

    /// `destination` is an insertion index into the list with the lifted
    /// card taken out of it — the same index `FollowingStore.move(_:to:)`
    /// takes, so what the screen shows and what gets persisted are the one
    /// number.
    private struct Lift {
        let table: FollowedTable
        var destination: Int
    }

    /// One card can't be reordered, so it shows no grip and takes no drags.
    private var isReorderable: Bool { rows.count > 1 }

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
        .onChange(of: cardGestureActive || gripGestureActive) { _, active in
            if !active { drop() }
        }
    }

    @ViewBuilder
    private func card(_ row: FollowedTableRow) -> some View {
        let table = row.table
        let isLifted = lift?.table == table
        let travel: CGFloat = isLifted ? translation : shift(for: table)
        HStack(spacing: 0) {
            content(row)
                // A lifted card must not also be a tapped one. The row's
                // links are `SwipeSafeButtonStyle`, so a real drag already
                // misses them, but a press-and-release that never moves
                // would still land — and holding a card is not asking to
                // open it.
                .allowsHitTesting(lift == nil)
            if isReorderable {
                grip(for: table)
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
        .gesture(pressAndDrag(table), including: isReorderable ? .all : .subviews)
        .accessibilityAction(named: "Move up") { move(table, by: -1) }
        .accessibilityAction(named: "Move down") { move(table, by: 1) }
    }

    @ViewBuilder
    private func content(_ row: FollowedTableRow) -> some View {
        switch row.content {
        case .poll(let polls, let league):
            Top25Row(polls: polls, league: league)
        case .conference(let conference):
            // No leader, no record (Andy, 2026-09-21). The hub answers
            // "which league", and a name plus a standing was two answers
            // to two questions in one row.
            ConferenceListRow(conference: conference, showsLeader: false)
        }
    }

    /// Trailing, where iOS puts a reorder handle — after the follow star,
    /// so the star keeps the position it has in every other list. It is a
    /// real handle, not decoration: a drag from here lifts the card with
    /// no press to wait out.
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

    /// The whole-card path: hold to lift, then drag. The press is what
    /// keeps this off the ScrollView's toes — a finger that moves before
    /// the press completes is scrolling, and this gesture fails and lets
    /// it. Half a second, UIKit's own drag-lift delay, and only a few
    /// points of drift, so a scroll that starts slowly still reads as a
    /// scroll.
    private func pressAndDrag(_ table: FollowedTable) -> some Gesture {
        LongPressGesture(minimumDuration: Self.cardHold, maximumDistance: Self.holdSlop)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($cardGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    beginLift(of: table)
                case .second(true, let drag):
                    beginLift(of: table)
                    if let drag { track(drag.translation.height) }
                default:
                    break
                }
            }
            .onEnded { _ in drop() }
    }

    /// The grip path: a shorter hold than the card's, because aiming at a
    /// handle already says most of what the press exists to find out. It
    /// still needs one: the grip used to lift on the first 3pt of movement,
    /// and a thumb scrolling down the right edge of the hub is exactly that.
    private func gripDrag(_ table: FollowedTable) -> some Gesture {
        LongPressGesture(minimumDuration: Self.gripHold, maximumDistance: Self.holdSlop)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($gripGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    beginLift(of: table)
                case .second(true, let drag):
                    beginLift(of: table)
                    if let drag { track(drag.translation.height) }
                default:
                    break
                }
            }
            .onEnded { _ in drop() }
    }

    /// How long a card must be held before it lifts.
    static let cardHold: Double = 0.5
    /// The grip's hold: shorter, because aiming at it is itself intent.
    static let gripHold: Double = 0.2
    /// How far a finger may drift during the hold and still be holding.
    /// Anything more is a scroll starting, and the lift stands down.
    static let holdSlop: CGFloat = 5

    /// Idempotent: both gesture paths call it on every change, and the
    /// first one through does the work.
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
            following.move(current.table, to: current.destination)
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
