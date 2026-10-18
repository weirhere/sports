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
struct FormationField: View {
    let league: League
    let top: Formation?
    let bottom: Formation?
    let topTeam: Team
    let bottomTeam: Team
    /// "DEN offense" — nil outside football, where the team is the unit.
    var topLabel: String? = nil
    var bottomLabel: String? = nil

    /// Names take the ink their surface asks for: off-white on turf, which
    /// is the same deep green in both modes (dark names on it read muddy
    /// — Andy, 2026-10-18, against FotMob's pitch); fixed dark ink on
    /// ice, which stays light in both; `textPrimary` on maple, which
    /// deepens in dark mode the way the page does.
    private var ink: Color {
        switch league {
        case .collegeFootball, .nfl: SurfaceColors.turfInk
        case .nhl: SurfaceColors.ink
        case .nba: .textPrimary
        }
    }

    @ScaledMetric(relativeTo: .caption2) private var rowHeight: CGFloat = 58
    /// A wing's slot is capped, so the wings sit at the edges and the gap
    /// between them is the field, not a share of it; a crowded wing row
    /// gives the gap up first and spreads evenly like a line.
    @ScaledMetric(relativeTo: .caption2) private var wingWidth: CGFloat = 74

    var body: some View {
        VStack(spacing: 0) {
            half(top, team: topTeam, label: topLabel, isTop: true)
            half(bottom, team: bottomTeam, label: bottomLabel, isTop: false)
        }
        .background(FieldMarkings(league: league))
        .padding(.vertical, Spacing.sm)
    }

    /// One side's rows. Row 0 is the line of engagement, so the top half
    /// lists its rows deepest-first and pins them to the midline. The team
    /// caption is a strip of its own at the half's far end — it used to
    /// float over the deepest row, where "JAX defense" landed on the free
    /// safety (Andy, 2026-10-18).
    private func half(_ formation: Formation?, team: Team, label: String?, isTop: Bool) -> some View {
        let rows = formation?.rows ?? []
        let ordered = isTop ? Array(rows.reversed()) : rows
        return VStack(spacing: 0) {
            if isTop { teamCaption(team, label: label) }
            if rows.isEmpty {
                Text("Lineup TBA")
                    .font(.meta)
                    .foregroundStyle(ink.opacity(0.85))
                    .frame(maxWidth: .infinity, minHeight: rowHeight * 2)
            } else {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, row in
                    rowView(row, team: team)
                        // Off the screen edge, now that the field is on it.
                        .padding(.horizontal, Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
            }
            if !isTop { teamCaption(team, label: label) }
        }
        .frame(maxWidth: .infinity, alignment: isTop ? .bottom : .top)
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func rowView(_ row: Formation.Row, team: Team) -> some View {
        switch row {
        case .line(let players):
            HStack(spacing: 0) {
                ForEach(players) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink)
                }
            }
        case .wings(let left, let right):
            HStack(spacing: 0) {
                ForEach(left) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink, maxWidth: wingWidth)
                }
                Spacer(minLength: 0)
                ForEach(right) { person in
                    FormationSlot(person: person, team: team, league: league, ink: ink, maxWidth: wingWidth)
                }
            }
        }
    }

    private func teamCaption(_ team: Team, label: String?) -> some View {
        HStack(spacing: Spacing.xs) {
            LogoImage(url: team.logoURL)
                .frame(width: 14, height: 14)
            Text(label ?? team.abbreviation ?? team.location)
                .font(.meta)
                .foregroundStyle(ink.opacity(0.85))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The surface itself, as `Canvas` fills and strokes in `SurfaceColors`:
/// turf in alternating ten-yard bands with chalk yard lines and hashes;
/// maple with the keys in the darker paint; ice with its red and blue
/// lines and creases, inside the boards. Each gets the marks that make
/// it recognisable at a glance and no more.
private struct FieldMarkings: View {
    let league: League

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let chalk = SurfaceColors.chalk

            func stroke(_ path: Path, _ color: Color, width: CGFloat = 1) {
                context.stroke(path, with: .color(color), lineWidth: width)
            }
            func horizontal(_ y: CGFloat, _ color: Color, width: CGFloat = 1) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                stroke(path, color, width: width)
            }

            switch league {
            case .collegeFootball, .nfl:
                // Ten-yard bands either side of the line of scrimmage,
                // alternating out from it the way the drive field's do.
                let step = size.height / 10
                for band in 0..<10 {
                    let rect = CGRect(x: 0, y: step * CGFloat(band), width: size.width, height: step + 0.5)
                    context.fill(Path(rect), with: .color(band.isMultiple(of: 2) ? SurfaceColors.turf
                                                                                  : SurfaceColors.turfAlternate))
                }
                // Faint, the way a broadcast's are: the names are the
                // brightest thing on the field, and the lines sit under them.
                for index in 1..<10 where index != 5 {
                    horizontal(step * CGFloat(index), chalk.opacity(0.28))
                }
                horizontal(midY, chalk.opacity(0.7), width: 2)
                // Hash marks down the inboard thirds.
                for index in 0..<40 {
                    let y = size.height / 40 * (CGFloat(index) + 0.5)
                    for x in [size.width * 0.38, size.width * 0.62] {
                        var path = Path()
                        path.move(to: CGPoint(x: x - 3, y: y))
                        path.addLine(to: CGPoint(x: x + 3, y: y))
                        stroke(path, chalk.opacity(0.28))
                    }
                }
            case .nba:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SurfaceColors.maple))
                let line = chalk.opacity(0.9)
                // A key at each end, its free-throw circle facing the middle.
                let keyWidth = size.width * 0.3, keyHeight = size.height * 0.22
                for top in [true, false] {
                    let y = top ? 0 : size.height - keyHeight
                    let key = CGRect(x: size.width / 2 - keyWidth / 2, y: y, width: keyWidth, height: keyHeight)
                    context.fill(Path(key), with: .color(SurfaceColors.paint))
                    stroke(Path(key), line)
                    let circleY = top ? keyHeight : size.height - keyHeight
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: size.width / 2, y: circleY), radius: keyWidth / 2,
                               startAngle: .degrees(top ? 0 : 180), endAngle: .degrees(top ? 180 : 360),
                               clockwise: false)
                    stroke(arc, line)
                }
                horizontal(midY, line, width: 1.5)
                stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 24, y: midY - 24, width: 48, height: 48)), line)
            case .nhl:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SurfaceColors.ice))
                let red = SurfaceColors.rinkRed, blue = SurfaceColors.blueLine
                horizontal(midY, red, width: 2)
                horizontal(size.height * 0.34, blue, width: 1.5)
                horizontal(size.height * 0.66, blue, width: 1.5)
                stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 24, y: midY - 24, width: 48, height: 48)), blue)
                for top in [true, false] {
                    let y = top ? size.height * 0.07 : size.height * 0.93
                    horizontal(y, red)
                    var crease = Path()
                    crease.addArc(center: CGPoint(x: size.width / 2, y: y), radius: 14,
                                  startAngle: .degrees(top ? 0 : 180), endAngle: .degrees(top ? 180 : 360),
                                  clockwise: false)
                    stroke(crease, red)
                }
                stroke(Path(CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)),
                       SurfaceColors.boards, width: 1.5)
            }
        }
    }
}
