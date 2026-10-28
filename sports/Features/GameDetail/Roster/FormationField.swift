import SwiftUI

/// The playing surface, portrait, with the away side's unit in the top
/// half and the home side's in the bottom, facing each other across the
/// midline — away first, the app's order for American sports (Andy,
/// 2026-10-18).
///
/// Painted as the place it pictures — turf, maple, ice — with the same
/// `SurfaceColors` the live Gamecast surfaces use (Andy, 2026-10-18:
/// "use a green background like we do on the current drive visual … a
/// beige background like the court … hockey is just white like ice").
/// That widens the color budget's fourth exception from live-only to
/// this field too; nothing else on the card takes color.
///
/// Every surface is 736pt at the default text size, 368 a half, and each
/// half is its rows and nothing else: no empty band at either end, and
/// the teams' names live on the card's strips rather than on the paint
/// (the Figma sheet "↳ Roster variants", 2026-10-27). The rows sit between
/// the markings, so no player is drawn across a line.
struct FormationField: View {
    let league: League
    let top: Formation?
    let bottom: Formation?
    let topTeam: Team
    let bottomTeam: Team

    /// Names take the ink their surface asks for — see `SurfaceColors.ink`.
    private var ink: Color { SurfaceColors.ink(for: league).text }

    /// The whole surface grows with the text, from 1 at the default size,
    /// so the rows' proportions — and the markings between them — hold.
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    /// A wing's slot is capped, so the wings sit at the edges and the gap
    /// between them is the field, not a share of it; a crowded wing row
    /// gives the gap up first and spreads evenly like a line.
    @ScaledMetric(relativeTo: .caption2) private var wingWidth: CGFloat = 74

    /// A half at the default text size.
    static let halfHeight: CGFloat = 368

    /// Each row's height, from the midline out, at the default text size:
    /// football's 92pt bands, four a half; the court's backcourt, then the
    /// frontcourt under the basket; the rink's forwards, the defense pair
    /// and the goalie. A row past the table takes its last height.
    static func rowHeights(for league: League) -> [CGFloat] {
        switch league {
        case .collegeFootball, .nfl: [92, 92, 92, 92]
        case .nba: [228, 140]
        case .nhl: [138, 120, 110]
        }
    }

    private func rowHeight(_ index: Int) -> CGFloat {
        let heights = Self.rowHeights(for: league)
        return heights[min(index, heights.count - 1)]
    }

    /// Both halves at one height: the taller of the two, and never less
    /// than the 368 that makes the surface 736.
    private var halfHeight: CGFloat {
        let tallest = [top, bottom].map { formation in
            (formation?.rows ?? []).indices.reduce(0) { $0 + rowHeight($1) }
        }.max() ?? 0
        return max(Self.halfHeight, tallest) * scale
    }

    var body: some View {
        let half = halfHeight
        VStack(spacing: 0) {
            self.half(top, team: topTeam, isTop: true, height: half)
            self.half(bottom, team: bottomTeam, isTop: false, height: half)
        }
        .background(FieldMarkings(league: league, scale: scale))
    }

    /// One side's rows. Row 0 is the line of engagement, so the top half
    /// lists its rows deepest-first and pins them to the midline.
    private func half(_ formation: Formation?, team: Team, isTop: Bool, height: CGFloat) -> some View {
        let rows = Array((formation?.rows ?? []).enumerated())
        let ordered = isTop ? Array(rows.reversed()) : rows
        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text("Lineup TBA")
                    .font(.meta)
                    .foregroundStyle(ink.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(ordered, id: \.offset) { index, row in
                    rowView(row, team: team)
                        // Off the screen edge, now that the field is on it.
                        .padding(.horizontal, Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight(index) * scale,
                               alignment: alignment(of: row, isTop: isTop))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: isTop ? .bottom : .top)
    }

    /// Centred in its row, except the goalie, who stands toward his own
    /// defense rather than in the middle of the space behind it — clear of
    /// the crease and the goal line at the end (the Figma sheet).
    private func alignment(of row: Formation.Row, isTop: Bool) -> Alignment {
        let isGoalie = league == .nhl && row.players.allSatisfy { $0.position?.uppercased() == "G" }
        guard isGoalie else { return .center }
        return isTop ? .bottom : .top
    }

    @ViewBuilder
    private func rowView(_ row: Formation.Row, team: Team) -> some View {
        let hairline = league == .nba ? 0.12 : 0.08
        switch row {
        case .line(let players):
            HStack(spacing: 0) {
                ForEach(players) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink, hairline: hairline)
                }
            }
        case .wings(let left, let right):
            HStack(spacing: 0) {
                ForEach(left) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink,
                                  maxWidth: wingWidth, hairline: hairline)
                }
                Spacer(minLength: 0)
                ForEach(right) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink,
                                  maxWidth: wingWidth, hairline: hairline)
                }
            }
        }
    }
}

/// The surface itself, as `Canvas` fills and strokes in `SurfaceColors.Starters`:
/// turf in alternating bands, one per row; maple with its keys, centre
/// line and circles in the paint; ice with its red and blue lines and
/// creases. Each gets the marks that make it recognisable at a glance and
/// no more, at 4pt so they read at a glance under 48pt discs (the Figma
/// sheet, 2026-10-27). Positions scale with the rows; line widths don't.
private struct FieldMarkings: View {
    let league: League
    let scale: CGFloat

    private static let lineWidth: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = Self.lineWidth

            /// A full-width line `width` tall, centred on `y`.
            func band(_ y: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: 0, y: y - width / 2, width: size.width, height: width)),
                             with: .color(color))
            }
            /// A ring stroked inside its `diameter`, the way the sheet draws them.
            func ring(center: CGPoint, diameter: CGFloat, _ color: Color) {
                let radius = diameter / 2 - width / 2
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                      width: radius * 2, height: radius * 2)),
                               with: .color(color), lineWidth: width)
            }

            switch league {
            case .collegeFootball, .nfl:
                // A band a row, alternating out from the line of scrimmage
                // the way the drive field's do. No yard lines or hashes:
                // the rows and the line of scrimmage, 2pt of chalk, are the
                // field's only marks.
                let step = FormationField.rowHeights(for: league)[0] * scale
                var band = 0
                while midY - step * CGFloat(band) > 0 {
                    let y = midY - step * CGFloat(band + 1)
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: step + 0.5)),
                                 with: .color(band.isMultiple(of: 2) ? SurfaceColors.Starters.turfAlternate
                                                                    : SurfaceColors.Starters.turf))
                    context.fill(Path(CGRect(x: 0, y: midY + step * CGFloat(band) - 0.5,
                                             width: size.width, height: step + 0.5)),
                                 with: .color(band.isMultiple(of: 2) ? SurfaceColors.Starters.turf
                                                                    : SurfaceColors.Starters.turfAlternate))
                    band += 1
                }
                context.fill(Path(CGRect(x: 0, y: midY - 1, width: size.width, height: 2)),
                             with: .color(SurfaceColors.chalk))
            case .nba:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SurfaceColors.Starters.maple))
                let line = SurfaceColors.Starters.paint
                // A key at each end, 30% of the width and 22% of the length,
                // open at the baseline; its free-throw circle, as wide as the
                // key, is centred on the key's end with the inside half under
                // the key's maple. The centre circle is the same width.
                let keyWidth = size.width * 0.3, keyHeight = size.height * 0.22
                let left = size.width / 2 - keyWidth / 2, right = size.width / 2 + keyWidth / 2
                for top in [true, false] {
                    let end = top ? keyHeight : size.height - keyHeight
                    ring(center: CGPoint(x: size.width / 2, y: end), diameter: keyWidth, line)
                    let key = CGRect(x: left, y: top ? 0 : end, width: keyWidth, height: keyHeight)
                    context.fill(Path(key), with: .color(SurfaceColors.Starters.maple))
                    let baseline = top ? 0 : size.height
                    let inner = top ? end - width / 2 : end + width / 2
                    var outline = Path()
                    outline.move(to: CGPoint(x: left + width / 2, y: baseline))
                    outline.addLine(to: CGPoint(x: left + width / 2, y: inner))
                    outline.addLine(to: CGPoint(x: right - width / 2, y: inner))
                    outline.addLine(to: CGPoint(x: right - width / 2, y: baseline))
                    context.stroke(outline, with: .color(line), lineWidth: width)
                }
                band(midY, line)
                ring(center: CGPoint(x: size.width / 2, y: midY), diameter: keyWidth, line)
            case .nhl:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SurfaceColors.Starters.ice))
                let red = SurfaceColors.Starters.rinkRed
                // The blue lines fall between the forwards and the pair.
                let blue = FormationField.rowHeights(for: league)[0] * scale
                band(midY - blue, SurfaceColors.Starters.blueLine)
                band(midY + blue, SurfaceColors.Starters.blueLine)
                band(midY, red)
                ring(center: CGPoint(x: size.width / 2, y: midY), diameter: 48, red)
                // Goal lines 20pt off the boards, each crease a half circle
                // centred on its line's inner edge and opening into the ice.
                let goal = 20 * scale
                for y in [goal, size.height - goal] {
                    band(y, red)
                    let isTop = y < midY
                    var crease = Path()
                    crease.addArc(center: CGPoint(x: size.width / 2, y: isTop ? y + width / 2 : y - width / 2),
                                  radius: 14 - width / 2,
                                  startAngle: .degrees(isTop ? 0 : 180), endAngle: .degrees(isTop ? 180 : 360),
                                  clockwise: false)
                    context.stroke(crease, with: .color(red), lineWidth: width)
                }
            }
        }
    }
}
