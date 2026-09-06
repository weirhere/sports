import SwiftUI

/// The Postseason tab: a bracket, drawn (Andy, 2026-09-06 — "connected
/// screen to screen with hairline dividers", from the ESPN playoff-bracket
/// and FotMob knockout references).
///
/// Deliberately not the card-list format every other pane uses. A round of
/// games is a list; a bracket is a *shape*, and the shape is the
/// information — which two games feed the next one. So the games become
/// individual match cards in columns, the selected round beside the one it
/// feeds, joined by hairline connectors.
///
/// **The connectors are earned, never assumed.** A line is drawn only where
/// a completed game's winner actually appears in a later game — read off
/// results, not inferred from seeds. ESPN publishes no bracket tree, and
/// guessing who *would* play whom is the same tiebreaker invention the
/// standings contract forbids. So an unplayed round shows its cards with no
/// lines yet, and the bracket wires itself up as the games finish. A wrong
/// line is far worse than a missing one.
struct PostseasonSection: View {
    let rounds: [PostseasonRound]
    /// The fixture that sits outside the bracket — the NFL's Pro Bowl.
    var exhibition: PostseasonRound?
    let selection: String?
    let onSelectRound: (String) -> Void

    /// Which edge the incoming round pushes from, set before every change
    /// so the slide matches the chip row's spatial order — the day swipe's
    /// rule (ScoresScreen, 2026-08-25).
    @State private var slideEdge: Edge = .trailing
    /// Nil until the first user change: the initial render has no
    /// direction, so it must not slide.
    @State private var slideAnimation: Animation?
    /// The pane's own width, which is what the two columns are sized from.
    @State private var paneWidth: CGFloat = 360

    /// Both columns fit the screen, so the bracket never scrolls sideways
    /// itself (Andy, 2026-09-06). That is what frees the horizontal axis
    /// for the round swipe — a bracket inside its own horizontal scroller
    /// would swallow every drag before the pane saw it.
    private static let columnGap: CGFloat = 28
    private static let edgeInset: CGFloat = Spacing.sm
    private static let cardHeight: CGFloat = 82
    private static let byeHeight: CGFloat = 46
    private static let cardGap = Spacing.sm

    private var cardWidth: CGFloat {
        max(120, (paneWidth - Self.columnGap - Self.edgeInset * 2) / 2)
    }

    private var activeIndex: Int {
        rounds.firstIndex { $0.name == selection } ?? 0
    }

    private var activeRound: PostseasonRound? {
        rounds.indices.contains(activeIndex) ? rounds[activeIndex] : nil
    }

    /// The round this one feeds, shown alongside so the bracket reads left
    /// to right — the last round has nothing to its right.
    private var nextRound: PostseasonRound? {
        round(at: activeIndex + 1)
    }

    private func round(at index: Int) -> PostseasonRound? {
        rounds.indices.contains(index) ? rounds[index] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            roundRow
            if activeRound != nil {
                pane
                exhibitionRow
            } else {
                StatusMessage(text: "No postseason games")
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { paneWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in paneWidth = width }
            }
        )
    }

    // MARK: - Rounds

    /// A scroller, unlike the Games tab's control row: five rounds of
    /// "Conference Championships" never fit a phone's width, and both
    /// references scroll theirs.
    ///
    /// The horizontal inset is a content margin, not padding — padding
    /// scrolls away with the content and clips the chips' rims, leaving the
    /// first chip flush against the edge at rest (Andy, 2026-09-06).
    private var roundRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(rounds) { round in
                    RoundChip(title: round.name,
                              isOn: round.name == activeRound?.name) {
                        select(round.name)
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .contentMargins(.horizontal, Spacing.md, for: .scrollContent)
        .padding(.horizontal, -Spacing.sm)
    }

    /// Every round change funnels through here so chip taps and swipes
    /// share one direction rule: the bracket slides the way the chips move.
    private func select(_ name: String) {
        guard name != activeRound?.name,
              let target = rounds.firstIndex(where: { $0.name == name }) else { return }
        slideEdge = target > activeIndex ? .trailing : .leading
        slideAnimation = .default
        onSelectRound(name)
    }

    // MARK: - The sliding pane

    private var pane: some View {
        bracketPane(at: activeIndex)
            .id(activeRound?.name ?? "")
            .transition(.push(from: slideEdge))
            .animation(slideAnimation, value: selection)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Threshold, not finger-tracked. A gesture that tracks the
            // finger has to claim the drag from its first movement, and
            // inside the page's vertical ScrollView the scroll wins that
            // fight every time — which is why the Scores day swipe can
            // track and this can't: that one is attached outside its scroll
            // view. `.onEnded` alone is the shape the entity pages' own tab
            // swipe already uses here (2026-08-29), and it commits with the
            // same directional push.
            .simultaneousGesture(roundSwipe)
    }

    /// A gesture-only accelerator, like the tab swipe it sits inside: every
    /// round stays one chip tap away, so nothing is swipe-gated. The ends
    /// are a quiet no-op rather than a bounce into nothing.
    private var roundSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5,
                      let target = round(at: activeIndex + (dx < 0 ? 1 : -1))
                else { return }
                select(target.name)
            }
    }

    /// The Pro Bowl, under the final rather than between the rounds — the
    /// bronze-final treatment (Andy, 2026-09-06). Only on the last round's
    /// screen, because that is where a fixture outside the bracket belongs:
    /// after it, not inside it.
    @ViewBuilder
    private var exhibitionRow: some View {
        if activeIndex == rounds.count - 1, let exhibition {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(exhibition.name)
                    .font(.rowMetaMedium)
                    .foregroundStyle(.textSecondary)
                ForEach(exhibition.games) { game in
                    NavigationLink(value: game) {
                        BracketMatchCard(game: game)
                            .frame(width: cardWidth, height: Self.cardHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Bracket

    @ViewBuilder
    private func bracketPane(at index: Int) -> some View {
        if let round = round(at: index) {
            let next = self.round(at: index + 1)
            Group {
                if let next, let pairing = Postseason.pairing(round: round.games,
                                                              next: next.games) {
                    paired(pairing)
                } else {
                    // Nothing connects these two rounds yet, so they are
                    // two lists side by side and say so — no lines, no
                    // implied order.
                    HStack(alignment: .top, spacing: Self.columnGap) {
                        plainColumn(round.games)
                        if let next { plainColumn(next.games) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.edgeInset)
            .overlayPreferenceValue(BracketAnchors.self) { anchors in
                GeometryReader { proxy in
                    connectors(in: proxy, anchors: anchors, round: round, next: next)
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// The drawn bracket: sources stacked on the left in bracket order,
    /// each next-round game placed level with the middle of its own
    /// sources. That placement is the whole point — a game sitting opposite
    /// what feeds it needs no line crossing the column to reach it.
    private func paired(_ pairing: BracketPairing) -> some View {
        let tops = Self.sourceTops(pairing.sources)
        let placements = Self.placements(for: pairing, sourceTops: tops)
        let height = max(
            (tops.last ?? 0) + Self.height(of: pairing.sources.last),
            (placements.map { $0.top + Self.cardHeight }.max() ?? 0)
        )
        return HStack(alignment: .top, spacing: Self.columnGap) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(pairing.sources.enumerated()), id: \.element.id) { index, source in
                    sourceView(source)
                        .frame(width: cardWidth, height: Self.height(of: source))
                        .offset(y: tops[index])
                }
            }
            .frame(width: cardWidth, height: height, alignment: .topLeading)
            ZStack(alignment: .topLeading) {
                ForEach(placements, id: \.game.id) { placement in
                    matchLink(placement.game)
                        .frame(width: cardWidth, height: Self.cardHeight)
                        .offset(y: placement.top)
                }
            }
            .frame(width: cardWidth, height: height, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func sourceView(_ source: BracketSource) -> some View {
        switch source {
        case .game(let game): matchLink(game)
        case .bye(let team): ByeCard(team: team).anchored(source.id)
        }
    }

    private func matchLink(_ game: Game) -> some View {
        NavigationLink(value: game) {
            BracketMatchCard(game: game)
        }
        .buttonStyle(.plain)
        .anchored("game-\(game.id)")
    }

    /// The fallback when nothing connects: plain columns, tightly stacked.
    private func plainColumn(_ games: [Game]) -> some View {
        VStack(spacing: Self.cardGap) {
            ForEach(games) { game in
                matchLink(game).frame(width: cardWidth, height: Self.cardHeight)
            }
        }
    }

    // MARK: - Bracket geometry

    private static func height(of source: BracketSource?) -> CGFloat {
        switch source {
        case .bye: byeHeight
        default: cardHeight
        }
    }

    /// Where each left-column slot starts. Cumulative rather than
    /// arithmetic, because a bye entry is shorter than a game.
    private static func sourceTops(_ sources: [BracketSource]) -> [CGFloat] {
        var tops: [CGFloat] = []
        var y: CGFloat = 0
        for source in sources {
            tops.append(y)
            y += height(of: source) + cardGap
        }
        return tops
    }

    /// Each next-round game centred on its own sources, then nudged down
    /// wherever two would overlap — a placement that collides is worse
    /// than one a few points off its ideal centre.
    private static func placements(for pairing: BracketPairing,
                                   sourceTops: [CGFloat]) -> [(game: Game, top: CGFloat)] {
        var ideal: [(game: Game, top: CGFloat)] = pairing.links.map { link in
            let centres = link.sourceIndices.compactMap { index -> CGFloat? in
                guard sourceTops.indices.contains(index) else { return nil }
                return sourceTops[index] + height(of: pairing.sources[index]) / 2
            }
            guard !centres.isEmpty else { return (link.game, 0) }
            let centre = centres.reduce(0, +) / CGFloat(centres.count)
            return (link.game, centre - cardHeight / 2)
        }
        ideal.sort { $0.top < $1.top }
        var placed: [(game: Game, top: CGFloat)] = []
        for entry in ideal {
            let floor = placed.last.map { $0.top + cardHeight + cardGap } ?? 0
            placed.append((entry.game, max(entry.top, floor)))
        }
        return placed
    }

    // MARK: - Connectors

    /// One hairline per source, drawn between the anchors the layout
    /// actually produced — including from a bye entry, which is an
    /// advancement like any other.
    @ViewBuilder
    private func connectors(in proxy: GeometryProxy, anchors: [String: Anchor<CGRect>],
                            round: PostseasonRound, next: PostseasonRound?) -> some View {
        if let next, let pairing = Postseason.pairing(round: round.games, next: next.games) {
            Path { path in
                for link in pairing.links {
                    guard let toAnchor = anchors["game-\(link.game.id)"] else { continue }
                    let to = proxy[toAnchor]
                    for index in link.sourceIndices {
                        guard pairing.sources.indices.contains(index),
                              let fromAnchor = anchors[pairing.sources[index].id] else { continue }
                        elbow(&path, from: proxy[fromAnchor], to: to)
                    }
                }
            }
            .stroke(Color.divider, style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    /// Horizontal out, a rounded turn, vertical, another turn, horizontal
    /// in — a bracket's own line. A feeder already level with its target
    /// draws straight through, since a curve with nothing to curve around
    /// reads as a wobble.
    private func elbow(_ path: inout Path, from: CGRect, to: CGRect) {
        let startX = from.maxX
        let startY = from.midY
        let endX = to.minX
        let endY = to.midY
        let midX = (startX + endX) / 2
        path.move(to: CGPoint(x: startX, y: startY))
        guard abs(startY - endY) > 1 else {
            path.addLine(to: CGPoint(x: endX, y: endY))
            return
        }
        let radius = min(8, abs(startY - endY) / 2, abs(midX - startX))
        let down = endY > startY
        path.addLine(to: CGPoint(x: midX - radius, y: startY))
        path.addQuadCurve(to: CGPoint(x: midX, y: startY + (down ? radius : -radius)),
                          control: CGPoint(x: midX, y: startY))
        path.addLine(to: CGPoint(x: midX, y: endY + (down ? -radius : radius)))
        path.addQuadCurve(to: CGPoint(x: midX + radius, y: endY),
                          control: CGPoint(x: midX, y: endY))
        path.addLine(to: CGPoint(x: endX, y: endY))
    }
}

private extension View {
    /// Publishes this card's frame so the connectors can be drawn between
    /// the positions the layout actually chose.
    func anchored(_ id: String) -> some View {
        anchorPreference(key: BracketAnchors.self, value: .bounds) { [id: $0] }
    }
}

/// A team that skipped this round. Quieter than a match card and half its
/// height — nothing happened here, and the card should say so without
/// taking a game's worth of space.
private struct ByeCard: View {
    let team: Team

    var body: some View {
        HStack(spacing: Spacing.xs) {
            LogoImage(url: team.logoURL, placeholder: nil)
                .frame(width: 16, height: 16)
            Text(team.abbreviation ?? team.location)
                .font(.rowNameEmphasis)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            Text("BYE")
                .font(.rowMetaMedium)
                .tracking(0.4)
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(team.location), bye")
    }
}

/// Where every match card is, so the connectors can be drawn between them
/// wherever the layout puts them — the pairing is derived from results, not
/// from position, so the lines can't be laid out by arithmetic.
private struct BracketAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// One game in the bracket: its own compact card, not a row in a list.
///
/// The loser gives up its ink rather than being struck through (FotMob
/// strikes; the app mutes, everywhere from GameRow to the widget) — one
/// convention, and a strike-through would be the only one in the app.
private struct BracketMatchCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Spacing.xs) {
                if game.isLive {
                    Circle().fill(Color.liveAccent).frame(width: 5, height: 5)
                }
                Text(statusLine)
                    .font(.rowMetaMedium)
                    .foregroundStyle(game.isLive ? .textPrimary : .textSecondary)
                    .lineLimit(1)
            }
            side(game.away)
            side(game.home)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.bgCard)
        )
        // A hairline, not the shadow the list cards wear: the connectors
        // are hairlines too, so the card edge and the line that meets it
        // are the same stroke.
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    private func side(_ competitor: Competitor) -> some View {
        let muted = isMuted(competitor)
        return HStack(spacing: Spacing.xs) {
            LogoImage(url: competitor.team.logoURL, placeholder: nil)
                .frame(width: 16, height: 16)
            if let rank = competitor.rank {
                Text("\(rank)")
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
            }
            Text(competitor.team.abbreviation ?? competitor.team.location)
                .font(muted ? .rowName : .rowNameEmphasis)
                .foregroundStyle(muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            if let score = competitor.score {
                Text("\(score)")
                    .font((muted ? Font.rowName : .rowNameEmphasis).monospacedDigit())
                    .foregroundStyle(muted ? .textSecondary : .textPrimary)
            }
        }
    }

    /// Only a decided game has a loser to mute — a pre-game card's two
    /// sides are equals.
    private func isMuted(_ competitor: Competitor) -> Bool {
        guard case .final = game.status else { return false }
        return competitor.winner == false
    }

    private var statusLine: String {
        switch game.status {
        case .final(let detail):
            if let detail, detail.localizedCaseInsensitiveContains("OT") { return "Final/OT" }
            return "Final"
        case .live:
            return game.status.liveStatusText ?? "Live"
        case .pre:
            guard let date = game.date else { return "TBD" }
            if game.timeTBD {
                return date.formatted(.dateTime.month(.defaultDigits).day())
            }
            return date.formatted(.dateTime.month(.defaultDigits).day().hour().minute())
        case .other(let detail):
            return detail ?? "—"
        }
    }

    private var spokenLabel: String {
        var parts = [game.headline].compactMap(\.self)
        parts.append("\(game.away.team.location) at \(game.home.team.location)")
        if let away = game.away.score, let home = game.home.score {
            parts.append("\(away) to \(home)")
        }
        parts.append(statusLine)
        return parts.joined(separator: ", ")
    }
}

/// The round selector's chip. Single-select, so it borrows the Games tab's
/// on/off chrome rather than inventing a third chip language.
private struct RoundChip: View {
    let title: String
    let isOn: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.chip)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isOn ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .modifier(SlateChipBackground(isActive: isOn))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(
            "postseason-round-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}
