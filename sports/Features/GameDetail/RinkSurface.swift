import SwiftUI

/// The hockey Gamecast's surface (2026-09-27): the whole rink, 200 × 85
/// feet with 28-foot corners, away shooting right every period (D5, D6).
/// White ice, the red lines in the app's one red and the blue lines in
/// gray, so no color joins the app for them (D13).
struct RinkSurface: View {
    let map: ShotMap
    let away: GameSummary.Side?
    let home: GameSummary.Side?
    let latestLogoURL: URL?

    private static let length: CGFloat = 200
    private static let width: CGFloat = 85

    var body: some View {
        Color.clear
            .aspectRatio(Self.length / Self.width, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let s = geo.size.width / Self.length
                    ZStack(alignment: .topLeading) {
                        Canvas { context, _ in
                            context.scaleBy(x: s, y: s)
                            Self.drawRink(in: &context, lineWidth: 1 / s)
                        }
                        ShotMarksLayer(map: map, scale: s, away: away, home: home,
                                       latestLogoURL: latestLogoURL)
                    }
                }
            }
            // Room for the pin over a shot by the top boards.
            .padding(.top, LogoPin.height)
            .accessibilityHidden(true)
    }

    private static func drawRink(in context: inout GraphicsContext, lineWidth: CGFloat) {
        let boards = Path(roundedRect: CGRect(x: 0, y: 0, width: length, height: width),
                          cornerRadius: 28)
        context.fill(boards, with: .color(SurfaceColors.ice))
        context.drawLayer { ice in
            ice.clip(to: boards)
            let red = GraphicsContext.Shading.color(SurfaceColors.rinkRed)
            let blue = GraphicsContext.Shading.color(SurfaceColors.blueLine)
            ice.fill(Path(CGRect(x: 99.5, y: 0, width: 1, height: width)), with: red)
            ice.fill(Path(CGRect(x: 74.5, y: 0, width: 1, height: width)), with: blue)
            ice.fill(Path(CGRect(x: 124.5, y: 0, width: 1, height: width)), with: blue)
            var redLines = Path()
            for x in [11.0, 189.0] as [CGFloat] {
                redLines.move(to: CGPoint(x: x, y: 0))
                redLines.addLine(to: CGPoint(x: x, y: width))
            }
            // End-zone faceoff circles, 15 ft, 22 ft either side of center.
            for x in [31.0, 169.0] as [CGFloat] {
                for y in [20.5, 64.5] as [CGFloat] {
                    redLines.addEllipse(in: CGRect(x: x - 15, y: y - 15, width: 30, height: 30))
                }
            }
            // The creases: half-circles out from each goal line.
            redLines.move(to: CGPoint(x: 11, y: 36.5))
            redLines.addArc(center: CGPoint(x: 11, y: 42.5), radius: 6,
                            startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            redLines.move(to: CGPoint(x: 189, y: 36.5))
            redLines.addArc(center: CGPoint(x: 189, y: 42.5), radius: 6,
                            startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            ice.stroke(redLines, with: red, lineWidth: lineWidth)
            ice.stroke(Path(ellipseIn: CGRect(x: 85, y: 27.5, width: 30, height: 30)),
                       with: blue, lineWidth: lineWidth)
        }
        context.stroke(boards, with: .color(SurfaceColors.boards), lineWidth: lineWidth * 1.5)
    }
}
