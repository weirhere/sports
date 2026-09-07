import SwiftUI

/// ESPN's Gamecast strip, monochrome: who has the ball, on what down,
/// where on the field, and what just happened. Live games only — it is
/// built from `drives.current`, which ESPN drops the moment a game ends,
/// so the card retires itself without a second condition.
///
/// No color. The header above already carries the live dot, and a field
/// this small reads on position and weight — the budget's rule that a
/// design problem wanting color usually wants spacing instead.
struct LiveSituationCard: View {
    let summary: GameSummary
    let situation: GameSituation

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 9

    private var offense: Team? { summary.team(withId: situation.possessionTeamId) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            downLine
            if situation.fieldPosition != nil {
                field
            }
            if let text = situation.lastPlayText {
                Text(text)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Mark, down and distance, then the spot — the three things a fan
    /// glancing at a live game asks for in that order.
    private var downLine: some View {
        HStack(spacing: Spacing.md) {
            LogoImage(url: offense?.logoURL, placeholder: nil)
                .frame(width: logoSize, height: logoSize)
            if let down = situation.downDistanceText {
                Text(down)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
            }
            if let spot = situation.possessionText {
                Text(spot)
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if let line = situation.driveSummary {
                Text(line)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    /// The away team's end zone is the left edge and the home team's the
    /// right, matching the header's logo order. The arrow says which way
    /// this offense is moving, so the marker's position can't be read
    /// backwards.
    private var field: some View {
        VStack(spacing: Spacing.xs) {
            GeometryReader { geo in
                let fraction = CGFloat(situation.fieldPosition ?? 0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.divider)
                        .frame(height: 4)
                    // Every 10 yards, with the 50 carrying full ink —
                    // ticks are what turn a bar into a field.
                    ForEach(1..<10) { yard in
                        Rectangle()
                            .fill(yard == 5 ? Color.textSecondary : Color.bgCard)
                            .frame(width: 1, height: yard == 5 ? 10 : 6)
                            .offset(x: geo.size.width * CGFloat(yard) / 10)
                    }
                    marker
                        .offset(x: geo.size.width * fraction - markerSize / 2)
                }
                .frame(height: 12, alignment: .center)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            HStack {
                Text(summary.away?.team.abbreviation ?? "")
                Spacer()
                Text("50")
                Spacer()
                Text(summary.home?.team.abbreviation ?? "")
            }
            .font(.rowMeta)
            .foregroundStyle(.textSecondary)
        }
    }

    private var marker: some View {
        HStack(spacing: 1) {
            if !situation.drivingRight { chevron(.left) }
            Circle()
                .fill(Color.textPrimary)
                .frame(width: markerSize, height: markerSize)
            if situation.drivingRight { chevron(.right) }
        }
    }

    private enum Direction { case left, right }

    private func chevron(_ direction: Direction) -> some View {
        Image(systemName: direction == .right ? "chevron.right" : "chevron.left")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.textPrimary)
    }

    /// "Washington State ball, 2nd & 4, WSU 26, 1 play, 6 yards, 0:05,
    /// (7:53) Shotgun #20 L.Pulalasi rush middle for 6 yards".
    /// Internal, not private, so the label shape is unit-testable.
    var accessibilitySummary: String {
        var parts: [String] = []
        if let name = offense?.location { parts.append("\(name) ball") }
        if let down = situation.downDistanceText { parts.append(down) }
        if let spot = situation.possessionText { parts.append(spot) }
        if let line = situation.driveSummary { parts.append(line) }
        if let text = situation.lastPlayText { parts.append(text) }
        return parts.joined(separator: ", ")
    }
}
