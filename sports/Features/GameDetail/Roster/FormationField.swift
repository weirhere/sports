import SwiftUI

/// The playing surface, portrait, with the away side's unit in the top
/// half and the home side's in the bottom, facing each other across the
/// midline — away first, the app's order for American sports (Andy,
/// 2026-10-18).
///
/// Monochrome, deliberately: the color budget's surface exception is for
/// the live Gamecast card and "only ever drawn while a game is live"
/// (2026-09-27), and this field draws before kickoff and after the final.
/// Gray lines on the recessed gray are enough to say "field"; the
/// headshots and the names carry the rest.
struct FormationField: View {
    let league: League
    let top: Formation?
    let bottom: Formation?
    let topTeam: Team
    let bottomTeam: Team
    /// "DEN offense" — nil outside football, where the team is the unit.
    var topLabel: String? = nil
    var bottomLabel: String? = nil

    @ScaledMetric(relativeTo: .caption2) private var rowHeight: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            half(top, team: topTeam, label: topLabel, isTop: true)
            half(bottom, team: bottomTeam, label: bottomLabel, isTop: false)
        }
        .background(FieldMarkings(league: league))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    /// One side's rows. Row 0 is the line of engagement, so the top half
    /// lists its rows deepest-first and pins them to the midline.
    private func half(_ formation: Formation?, team: Team, label: String?, isTop: Bool) -> some View {
        let rows = formation?.rows ?? []
        let ordered = isTop ? Array(rows.reversed()) : rows
        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text("Lineup TBA")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: rowHeight * 2)
            } else {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(row) { person in
                            FormationSlot(person: person, team: team, league: league)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight * 2, alignment: isTop ? .bottom : .top)
        .padding(.vertical, Spacing.xs)
        .overlay(alignment: isTop ? .topLeading : .bottomLeading) {
            teamCaption(team, label: label)
        }
    }

    private func teamCaption(_ team: Team, label: String?) -> some View {
        HStack(spacing: Spacing.xs) {
            LogoImage(url: team.logoURL)
                .frame(width: 14, height: 14)
            Text(label ?? team.abbreviation ?? team.location)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .padding(Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

/// The lines of a field, court or rink, as `Canvas` strokes in the one
/// gray. Each surface gets the marks that make it recognisable at a
/// glance and no more: yard lines, a center circle and keys, blue lines
/// and creases.
private struct FieldMarkings: View {
    let league: League

    var body: some View {
        Canvas { context, size in
            let line = Color.textSecondary.opacity(0.28)
            let midY = size.height / 2
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.bgElevated))

            func stroke(_ path: Path, width: CGFloat = 1) {
                context.stroke(path, with: .color(line), lineWidth: width)
            }
            func horizontal(_ y: CGFloat, width: CGFloat = 1) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                stroke(path, width: width)
            }

            switch league {
            case .collegeFootball, .nfl:
                // Yard lines either side of the line of scrimmage.
                let step = size.height / 10
                for index in 1..<10 where index != 5 {
                    horizontal(step * CGFloat(index))
                }
                horizontal(midY, width: 2)
                // Hash marks down the inboard thirds.
                for index in 0..<40 {
                    let y = size.height / 40 * (CGFloat(index) + 0.5)
                    for x in [size.width * 0.38, size.width * 0.62] {
                        var path = Path()
                        path.move(to: CGPoint(x: x - 3, y: y))
                        path.addLine(to: CGPoint(x: x + 3, y: y))
                        stroke(path)
                    }
                }
            case .nba:
                horizontal(midY)
                stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 24, y: midY - 24, width: 48, height: 48)))
                // A key at each end, its free-throw circle facing the middle.
                let keyWidth = size.width * 0.3, keyHeight = size.height * 0.22
                for top in [true, false] {
                    let y = top ? 0 : size.height - keyHeight
                    stroke(Path(CGRect(x: size.width / 2 - keyWidth / 2, y: y, width: keyWidth, height: keyHeight)))
                    let circleY = top ? keyHeight : size.height - keyHeight
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: size.width / 2, y: circleY), radius: keyWidth / 2,
                               startAngle: .degrees(top ? 0 : 180), endAngle: .degrees(top ? 180 : 360),
                               clockwise: false)
                    stroke(arc)
                }
            case .nhl:
                horizontal(midY, width: 2)
                horizontal(size.height * 0.34)
                horizontal(size.height * 0.66)
                stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 24, y: midY - 24, width: 48, height: 48)))
                for top in [true, false] {
                    let y = top ? size.height * 0.07 : size.height * 0.93
                    horizontal(y)
                    var crease = Path()
                    crease.addArc(center: CGPoint(x: size.width / 2, y: y), radius: 14,
                                  startAngle: .degrees(top ? 0 : 180), endAngle: .degrees(top ? 180 : 360),
                                  clockwise: false)
                    stroke(crease)
                }
            }
        }
    }
}
