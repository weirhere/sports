import SwiftUI

/// A period's shots over a court or rink (2026-09-27). Shape says what
/// happened and color says whose (D10): filled for a make or a shot on
/// goal, a ring for a miss, a cross for a block, a larger disc for a goal.
/// The newest shot scales in over 0.6s with the pin moving onto it, the
/// field's timing (D8); a card that appears mid-period shows its state
/// without replaying it.
///
/// Marks are sized in points, not surface units, so a shot reads the same
/// on the court and the rink even though the two scale differently.
struct ShotMarksLayer: View {
    let map: ShotMap
    /// Points per surface unit.
    let scale: CGFloat
    let away: GameSummary.Side?
    let home: GameSummary.Side?
    let latestLogoURL: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        let colors = (away: teamColor(away), home: teamColor(home))
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for mark in map.marks.dropLast() {
                    Self.draw(mark, at: point(mark),
                              color: mark.side == .away ? colors.away : colors.home,
                              in: &context)
                }
            }
            if let latest = map.latest {
                LatestShot(mark: latest,
                           color: latest.side == .away ? colors.away : colors.home,
                           animates: hasAppeared && !reduceMotion)
                    .position(point(latest))
                    .id(latest.id)
                LogoPin(logoURL: latestLogoURL)
                    .position(x: point(latest).x, y: point(latest).y - LogoPin.height / 2)
                    .animation(hasAppeared && !reduceMotion ? .easeOut(duration: 0.6) : nil,
                               value: latest.id)
            }
        }
        .onAppear { hasAppeared = true }
    }

    private func point(_ mark: ShotMap.Mark) -> CGPoint {
        CGPoint(x: mark.x * scale, y: mark.y * scale)
    }

    /// Court and ice are light in both modes, so a mark asks for the color
    /// that reads on a light ground whatever the page is doing.
    private func teamColor(_ side: GameSummary.Side?) -> Color {
        SurfaceColors.teamMark(primary: side?.color, alternate: side?.alternateColor, isDark: false)
    }

    static func draw(_ mark: ShotMap.Mark, at p: CGPoint, color: Color,
                     in context: inout GraphicsContext) {
        func disc(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }
        switch mark.outcome {
        case .made:
            context.fill(disc(3.4), with: .color(color))
            context.stroke(disc(3.4), with: .color(SurfaceColors.chalk), lineWidth: 1)
        case .goal:
            context.fill(disc(5.4), with: .color(color))
            context.stroke(disc(5.4), with: .color(SurfaceColors.chalk), lineWidth: 1.5)
        case .missed:
            context.stroke(disc(2.8), with: .color(color), lineWidth: 1.5)
        case .blocked:
            var cross = Path()
            cross.move(to: CGPoint(x: p.x - 2.8, y: p.y - 2.8))
            cross.addLine(to: CGPoint(x: p.x + 2.8, y: p.y + 2.8))
            cross.move(to: CGPoint(x: p.x + 2.8, y: p.y - 2.8))
            cross.addLine(to: CGPoint(x: p.x - 2.8, y: p.y + 2.8))
            context.stroke(cross, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

/// The newest shot, on its own so a new one can scale in without
/// redrawing the rest.
private struct LatestShot: View {
    let mark: ShotMap.Mark
    let color: Color
    let animates: Bool

    @State private var grown: Bool

    init(mark: ShotMap.Mark, color: Color, animates: Bool) {
        self.mark = mark
        self.color = color
        self.animates = animates
        _grown = State(initialValue: !animates)
    }

    var body: some View {
        Canvas { context, size in
            ShotMarksLayer.draw(mark, at: CGPoint(x: size.width / 2, y: size.height / 2),
                                color: color, in: &context)
        }
        .frame(width: 14, height: 14)
        .scaleEffect(grown ? 1 : 0.01)
        .onAppear {
            guard animates else { return }
            withAnimation(.easeOut(duration: 0.6)) { grown = true }
        }
    }
}
