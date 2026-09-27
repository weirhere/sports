import SwiftUI

/// ESPN's Gamecast field (2026-09-27): the current drive drawn where it
/// happened. A trail from the drive's first snap to where the last play
/// began, the last play over it — straight on the ground, an arc through
/// the air — the offense's logo pinned above the ball, and the line to gain.
///
/// Drawn in a 360 × 85.5 unit space, scaled to the card's width, so the
/// field keeps its proportions on every phone: 10-yard end zones and
/// 100 yards of turf at 3 units a yard, the away end zone on the left to
/// match the header's logo order. The turf is the color budget's fourth
/// exception — see `FieldColors`.
struct DriveField: View {
    let field: GameSituation.Field
    let away: GameSummary.Side?
    let home: GameSummary.Side?
    let offenseLogoURL: URL?
    /// A new id draws the new play in; the same id, polled again, is left
    /// alone.
    let playId: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False for the first frame, so a card that appears mid-drive shows
    /// the last play already drawn rather than replaying it.
    @State private var hasAppeared = false

    private static let width: CGFloat = 360
    private static let turfTop: CGFloat = 40
    private static let turfHeight: CGFloat = 27.5
    private static let height: CGFloat = 85.5
    private static var midline: CGFloat { turfTop + turfHeight / 2 }

    /// Yards from the away goal line to units from the left edge.
    private static func x(_ yard: Double) -> CGFloat { 30 + 3 * CGFloat(yard) }

    var body: some View {
        Color.clear
            .aspectRatio(Self.width / Self.height, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let s = geo.size.width / Self.width
                    ZStack(alignment: .topLeading) {
                        turf(scale: s)
                        labels(scale: s)
                        marks(scale: s)
                        if let start = field.playStart, abs(start - field.ball) >= 0.5 {
                            PlayArrow(from: point(start, s), to: point(field.ball, s),
                                      isPass: field.isPass,
                                      peak: arcPeak(from: start, to: field.ball) * s,
                                      animates: hasAppeared && !reduceMotion)
                                .id(playId)
                        }
                        pin
                            .position(x: Self.x(field.ball) * s,
                                      y: Self.turfTop * s - Pin.height / 2 - 2)
                            .animation(hasAppeared && !reduceMotion ? .easeOut(duration: 0.6) : nil,
                                       value: field.ball)
                    }
                }
            }
            .onAppear { hasAppeared = true }
            // The card's own label already speaks the down, the spot and the
            // drive; the drawing repeats it.
            .accessibilityHidden(true)
    }

    private func point(_ yard: Double, _ s: CGFloat) -> CGPoint {
        CGPoint(x: Self.x(yard) * s, y: Self.midline * s)
    }

    /// How high a pass climbs, in units above the midline: longer throws
    /// arc higher, capped so a bomb stays on the card.
    private func arcPeak(from start: Double, to end: Double) -> CGFloat {
        min(34, 10 + abs(Self.x(end) - Self.x(start)) * 0.35)
    }

    // MARK: - Turf

    private func turf(scale s: CGFloat) -> some View {
        let awayZone = endZone(away)
        let homeZone = endZone(home)
        return Canvas { context, _ in
            context.scaleBy(x: s, y: s)
            let h = Self.turfHeight
            context.fill(Path(CGRect(x: 0, y: 0, width: 30, height: h)), with: .color(awayZone))
            context.fill(Path(CGRect(x: 330, y: 0, width: 30, height: h)), with: .color(homeZone))
            for band in 0..<10 {
                context.fill(Path(CGRect(x: 30 + 30 * CGFloat(band), y: 0, width: 30, height: h)),
                             with: .color(band.isMultiple(of: 2) ? FieldColors.turf : FieldColors.turfAlternate))
            }
            for yard in stride(from: 10, to: 100, by: 10) where yard != 50 {
                line(at: Self.x(Double(yard)), in: &context, height: h, opacity: 0.45, width: 1 / s)
            }
            for edge in [30.0, 180, 330] as [CGFloat] {
                line(at: edge, in: &context, height: h, opacity: 0.9, width: 1.5 / s)
            }
        }
        .frame(width: Self.width * s, height: Self.turfHeight * s)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .offset(y: Self.turfTop * s)
    }

    private func line(at x: CGFloat, in context: inout GraphicsContext,
                      height: CGFloat, opacity: Double, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: height))
        context.stroke(path, with: .color(FieldColors.chalk.opacity(opacity)), lineWidth: width)
    }

    private func endZone(_ side: GameSummary.Side?) -> Color {
        FieldColors.endZone(primary: side?.color, alternate: side?.alternateColor,
                            isDark: colorScheme == .dark)
    }

    // MARK: - Labels

    private func labels(scale s: CGFloat) -> some View {
        let y = (Self.turfTop + Self.turfHeight + 11) * s
        return ZStack(alignment: .topLeading) {
            label(away?.team.abbreviation ?? "", emphasized: true).position(x: 15 * s, y: y)
            label("20", emphasized: false).position(x: Self.x(20) * s, y: y)
            label("50", emphasized: false).position(x: Self.x(50) * s, y: y)
            label("20", emphasized: false).position(x: Self.x(80) * s, y: y)
            label(home?.team.abbreviation ?? "", emphasized: true).position(x: 345 * s, y: y)
        }
    }

    private func label(_ text: String, emphasized: Bool) -> some View {
        Text(text)
            .font((emphasized ? Font.rowMetaMedium : .rowMeta).monospacedDigit())
            .foregroundStyle(emphasized ? .textPrimary : .textSecondary)
            .fixedSize()
    }

    // MARK: - Trail, start and line to gain

    private func marks(scale s: CGFloat) -> some View {
        Canvas { context, _ in
            context.scaleBy(x: s, y: s)
            if let gain = field.lineToGain {
                var path = Path()
                path.move(to: CGPoint(x: Self.x(gain), y: Self.turfTop - 3))
                path.addLine(to: CGPoint(x: Self.x(gain), y: Self.turfTop + Self.turfHeight + 3))
                context.stroke(path, with: .color(FieldColors.lineToGain), lineWidth: 2 / s)
            }
            guard let start = field.driveStart else { return }
            let from = Self.x(start)
            let to = Self.x(field.playStart ?? field.ball)
            if abs(to - from) >= 0.5 {
                var trail = Path()
                trail.move(to: CGPoint(x: from, y: Self.midline))
                trail.addLine(to: CGPoint(x: to, y: Self.midline))
                context.stroke(trail, with: .color(FieldColors.chalk),
                               style: StrokeStyle(lineWidth: 2 / s, lineCap: .round))
            }
            let dot = Path(ellipseIn: CGRect(x: from - 3.2, y: Self.midline - 3.2, width: 6.4, height: 6.4))
            context.fill(dot, with: .color(FieldColors.chalk))
            context.stroke(dot, with: .color(FieldColors.ink), lineWidth: 1.5 / s)
        }
        .frame(width: Self.width * s, height: Self.height * s)
    }

    // MARK: - Pin

    private var pin: some View {
        ZStack(alignment: .top) {
            Pin()
                .fill(Color.bgCard)
                .overlay(Pin().stroke(Color.divider, lineWidth: 1))
            LogoImage(url: offenseLogoURL, placeholder: nil)
                .frame(width: 17, height: 17)
                .padding(.top, 4.5)
        }
        .frame(width: Pin.width, height: Pin.height)
    }
}

/// The last play: drawn in over 0.6s when it's new, with its arrowhead
/// landing as the line arrives.
private struct PlayArrow: View {
    let from: CGPoint
    let to: CGPoint
    let isPass: Bool
    /// Points above the midline the arc's control point sits at.
    let peak: CGFloat
    let animates: Bool

    @State private var progress: CGFloat
    @State private var headOpacity: Double

    init(from: CGPoint, to: CGPoint, isPass: Bool, peak: CGFloat, animates: Bool) {
        self.from = from
        self.to = to
        self.isPass = isPass
        self.peak = peak
        self.animates = animates
        _progress = State(initialValue: animates ? 0 : 1)
        _headOpacity = State(initialValue: animates ? 0 : 1)
    }

    private var control: CGPoint {
        CGPoint(x: (from.x + to.x) / 2, y: from.y - 2 * peak)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayPath(from: from, to: to, control: isPass ? control : nil)
                .trim(from: 0, to: progress)
                .stroke(FieldColors.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Arrowhead()
                .fill(FieldColors.ink)
                .frame(width: 8, height: 8)
                .rotationEffect(headAngle)
                .position(to)
                .opacity(headOpacity)
        }
        .onAppear {
            guard animates else { return }
            withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
            withAnimation(.easeOut(duration: 0.12).delay(0.52)) { headOpacity = 1 }
        }
    }

    /// The direction of travel as the line arrives — along the ground, or
    /// down the arc's last stretch.
    private var headAngle: Angle {
        let origin = isPass ? control : from
        return .radians(atan2(to.y - origin.y, to.x - origin.x))
    }
}

private struct PlayPath: Shape {
    let from: CGPoint
    let to: CGPoint
    let control: CGPoint?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        if let control {
            path.addQuadCurve(to: to, control: control)
        } else {
            path.addLine(to: to)
        }
        return path
    }
}

/// Points right; the view rotates it to the play's direction. Its tip sits
/// on the frame's center so `.position(to)` lands it on the ball.
private struct Arrowhead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX - rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX - rect.width / 2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A map pin: a disc for the logo with a point beneath it.
private struct Pin: Shape {
    static let width: CGFloat = 26
    static let height: CGFloat = 33

    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: radius)
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(145), endAngle: .degrees(35), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
