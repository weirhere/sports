import SwiftUI

/// The baseball Gamecast's surface (2026-11-03): the infield from behind
/// home plate, grass in the turf's green with the diamond cut into it in
/// infield dirt, and the three bags — an occupied one filled in the batting
/// team's color, the way a shot mark wears its shooter's. The color
/// budget's fourth exception, `SurfaceColors`; the card around it stays
/// monochrome. The count and the outs ride the card's header, not the
/// picture.
struct DiamondSurface: View {
    let diamond: BaseballDiamond
    let away: GameSummary.Side?
    let home: GameSummary.Side?

    /// Wider than tall: the diamond's own square, with grass to either side.
    private static let aspect: CGFloat = 2.2

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspect, contentMode: .fit)
            .overlay {
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .accessibilityHidden(true)
    }

    private var runnerColor: Color {
        let side = diamond.battingSide == .away ? away : home
        // Dirt is mid-toned in both modes, so a mark is checked as on a
        // light ground, the court's rule.
        return SurfaceColors.teamMark(primary: side?.color, alternate: side?.alternateColor,
                                      isDark: false)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SurfaceColors.turf))
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let reach = size.height * 0.40
        let home = CGPoint(x: center.x, y: center.y + reach)
        let first = CGPoint(x: center.x + reach, y: center.y)
        let second = CGPoint(x: center.x, y: center.y - reach)
        let third = CGPoint(x: center.x - reach, y: center.y)

        // The dirt: the skin around the bases, a little wider than the
        // basepaths, with the infield grass inside.
        let skin = reach * 1.18
        var dirt = Path()
        dirt.addLines([CGPoint(x: center.x, y: center.y + skin), CGPoint(x: center.x + skin, y: center.y),
                       CGPoint(x: center.x, y: center.y - skin), CGPoint(x: center.x - skin, y: center.y)])
        dirt.closeSubpath()
        context.fill(dirt, with: .color(SurfaceColors.infieldDirt))
        let lawn = reach * 0.72
        var grass = Path()
        grass.addLines([CGPoint(x: center.x, y: center.y + lawn), CGPoint(x: center.x + lawn, y: center.y),
                        CGPoint(x: center.x, y: center.y - lawn), CGPoint(x: center.x - lawn, y: center.y)])
        grass.closeSubpath()
        context.fill(grass, with: .color(SurfaceColors.turf))

        // The foul lines, out from home past the corners.
        var lines = Path()
        lines.move(to: home)
        lines.addLine(to: CGPoint(x: home.x + size.width, y: home.y - size.width))
        lines.move(to: home)
        lines.addLine(to: CGPoint(x: home.x - size.width, y: home.y - size.width))
        context.stroke(lines, with: .color(SurfaceColors.chalk.opacity(0.85)), lineWidth: 1.5)

        // The mound.
        let mound = reach * 0.16
        context.fill(Path(ellipseIn: CGRect(x: center.x - mound, y: center.y - mound,
                                            width: mound * 2, height: mound * 2)),
                     with: .color(SurfaceColors.infieldDirt))

        // Home plate, then the bags: a filled bag is a runner.
        let bag = max(10, reach * 0.22)
        context.fill(Path(CGRect(x: home.x - bag / 3, y: home.y - bag / 3,
                                 width: bag * 2 / 3, height: bag * 2 / 3)),
                     with: .color(SurfaceColors.chalk))
        for (point, occupied) in [(first, diamond.onFirst), (second, diamond.onSecond),
                                  (third, diamond.onThird)] {
            let square = Path(CGRect(x: -bag / 2, y: -bag / 2, width: bag, height: bag))
                .applying(CGAffineTransform(rotationAngle: .pi / 4))
                .applying(CGAffineTransform(translationX: point.x, y: point.y))
            if occupied {
                context.fill(square, with: .color(runnerColor))
                context.stroke(square, with: .color(SurfaceColors.chalk), lineWidth: 2)
            } else {
                context.fill(square, with: .color(SurfaceColors.chalk.opacity(0.35)))
                context.stroke(square, with: .color(SurfaceColors.chalk), lineWidth: 1.5)
            }
        }
    }
}
