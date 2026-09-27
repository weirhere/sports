import SwiftUI

/// The basketball Gamecast's surface (2026-09-27): the whole court,
/// landscape, 94 × 50 feet, home shooting at the left basket and away at
/// the right (D5, D6). Maple with the keys a shade darker and chalk
/// lines, the color budget's fourth exception — see `SurfaceColors`.
struct CourtSurface: View {
    let map: ShotMap
    let away: GameSummary.Side?
    let home: GameSummary.Side?
    let latestLogoURL: URL?

    private static let length: CGFloat = 94
    private static let width: CGFloat = 50

    var body: some View {
        Color.clear
            .aspectRatio(Self.length / Self.width, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let s = geo.size.width / Self.length
                    ZStack(alignment: .topLeading) {
                        Canvas { context, _ in
                            context.scaleBy(x: s, y: s)
                            Self.drawCourt(in: &context, lineWidth: 1 / s)
                        }
                        // The court's corners, not the pin's: a shot on the
                        // top sideline puts the pin above the court.
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        ShotMarksLayer(map: map, scale: s, away: away, home: home,
                                       latestLogoURL: latestLogoURL)
                    }
                }
            }
            // Room for the pin over a shot on the top sideline.
            .padding(.top, LogoPin.height)
            .accessibilityHidden(true)
    }

    private static func drawCourt(in context: inout GraphicsContext, lineWidth: CGFloat) {
        let chalk = GraphicsContext.Shading.color(SurfaceColors.chalk)
        context.fill(Path(CGRect(x: 0, y: 0, width: length, height: width)),
                     with: .color(SurfaceColors.maple))
        for end in [false, true] {
            // One end drawn in basket-left coordinates, the other mirrored.
            func x(_ v: CGFloat) -> CGFloat { end ? length - v : v }
            context.fill(Path(CGRect(x: min(x(0), x(19)), y: 17, width: 19, height: 16)),
                         with: .color(SurfaceColors.paint))
            var lines = Path()
            lines.addRect(CGRect(x: min(x(0), x(19)), y: 17, width: 19, height: 16))
            lines.addEllipse(in: CGRect(x: x(19) - 6, y: 19, width: 12, height: 12))
            // The three-point line: straight in the corners, 22 ft out,
            // then an arc 23.75 ft from the rim.
            let rim = CGPoint(x: x(5.25), y: 25)
            lines.move(to: CGPoint(x: x(0), y: 3))
            lines.addLine(to: CGPoint(x: x(14.2), y: 3))
            lines.addArc(center: rim, radius: 23.75,
                         startAngle: .degrees(end ? 247.8 : -67.8),
                         endAngle: .degrees(end ? 112.2 : 67.8), clockwise: end)
            lines.addLine(to: CGPoint(x: x(0), y: 47))
            lines.move(to: CGPoint(x: x(4), y: 22))
            lines.addLine(to: CGPoint(x: x(4), y: 28))
            lines.addEllipse(in: CGRect(x: rim.x - 0.75, y: 24.25, width: 1.5, height: 1.5))
            context.stroke(lines, with: chalk, lineWidth: lineWidth)
        }
        var middle = Path()
        middle.addRect(CGRect(x: 0, y: 0, width: length, height: width))
        middle.move(to: CGPoint(x: length / 2, y: 0))
        middle.addLine(to: CGPoint(x: length / 2, y: width))
        middle.addEllipse(in: CGRect(x: length / 2 - 6, y: 19, width: 12, height: 12))
        context.stroke(middle, with: chalk, lineWidth: lineWidth * 1.5)
    }
}
