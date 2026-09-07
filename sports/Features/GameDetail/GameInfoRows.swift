import SwiftUI

/// The "Game info" card's body, shared by both of the card's lives: the
/// pre-kick one that carries the whole "what do I need to know" load
/// (kickoff, where to watch, the forecast) and the played one that just
/// places the game and counts the crowd.
///
/// The venue is the card's headline — name in ink, city beneath it in
/// meta gray (FotMob's treatment) — and the crowd numbers below it are
/// label/value pairs in the team-page cards' language. Capacity is
/// always shown; attendance joins it the moment ESPN publishes one, and
/// the pair earns a fill meter in ink, never color.
struct GameInfoRows: View {
    let game: Game
    let summary: GameSummary
    /// Pre-kick only. Once a game has scores, kickoff time, the network,
    /// and the forecast are answered questions.
    var showsKickoffDetails: Bool = false

    /// Whether the played-game card has anything to say — its gate, the
    /// `MatchupStandings.hasContent` precedent.
    static func hasVenueContent(_ summary: GameSummary) -> Bool {
        summary.venue != nil || summary.attendance != nil
            || summary.venueCapacity != nil || summary.grassSurface != nil
    }

    private var surface: String? { summary.grassSurface.map { $0 ? "Grass" : "Turf" } }

    private var weatherLine: String {
        [summary.weatherTemperature.map { "\($0)°" }, summary.weatherCondition]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsKickoffDetails {
                if let date = game.date {
                    infoRow("calendar",
                            game.timeTBD
                                ? "\(GameRow.relativeKickParts(date, weekday: .abbreviated).day) · Kickoff TBD"
                                : GameRow.relativeKick(date, weekday: .abbreviated))
                }
                if let broadcast = game.broadcast {
                    infoRow("tv", broadcast)
                }
                if game.date != nil || game.broadcast != nil,
                   Self.hasVenueContent(summary) {
                    zoneDivider
                }
            }
            venueZone
            if showsKickoffDetails, !weatherLine.isEmpty {
                if Self.hasVenueContent(summary) {
                    zoneDivider
                }
                infoRow("cloud.sun", weatherLine)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// One icon-led line — the card's original row shape, kept for the
    /// facts that are a single sentence each.
    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    private var zoneDivider: some View {
        Divider().overlay(Color.divider)
            .padding(.leading, Spacing.lg)
            .padding(.vertical, Spacing.xs)
    }

    /// Where the game is, and how full it was.
    @ViewBuilder
    private var venueZone: some View {
        if let venue = summary.venue {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(venue)
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                    if let city = summary.venueCity {
                        Text(city)
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .accessibilityElement(children: .combine)
        }
        crowdRows
    }

    /// Attendance and capacity, FotMob's pairing: once attendance is
    /// public it takes the leading slot and capacity becomes its context,
    /// with the meter saying how full that made the place. Before then,
    /// capacity leads on its own beside the surface.
    @ViewBuilder
    private var crowdRows: some View {
        if let attendance = summary.attendance {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    metric("Attendance", attendance.formatted())
                    Spacer(minLength: Spacing.sm)
                    if let capacity = summary.venueCapacity {
                        metric("Capacity", capacity.formatted())
                    }
                }
                if let capacity = summary.venueCapacity, capacity > 0 {
                    fillMeter(attendance: attendance, capacity: capacity)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(crowdAccessibilityLabel(attendance))
            if let surface {
                pairRow("Surface", surface)
            }
        } else if let capacity = summary.venueCapacity {
            HStack(spacing: Spacing.md) {
                metric("Capacity", capacity.formatted())
                Spacer(minLength: Spacing.sm)
                if let surface {
                    metric("Surface", surface)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .accessibilityElement(children: .combine)
        } else if let surface {
            // Alone, the surface is just another leading-aligned row —
            // the Spacer above only exists to split a *pair* across the
            // card, and with nothing on its left it would push this one
            // to the trailing edge, out of line with everything else.
            pairRow("Surface", surface)
        }
    }

    private func pairRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.md) {
            metric(label, value)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    /// The team-page cards' label/value language: gray label, ink value.
    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Text(value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
    }

    /// Ink on a hairline track — a meter is chrome, so the color budget
    /// holds. Overflowing crowds (standing room beats the printed
    /// capacity) clamp the fill and still report their real percentage.
    private func fillMeter(attendance: Int, capacity: Int) -> some View {
        let fraction = min(Double(attendance) / Double(capacity), 1)
        return HStack(spacing: Spacing.sm) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.divider)
                    Capsule().fill(Color.textPrimary)
                        .frame(width: max(proxy.size.width * fraction, 4))
                }
            }
            .frame(height: 6)
            Text("\(Self.fillPercent(attendance: attendance, capacity: capacity))%")
                .font(.rowMetaMedium)
                .monospacedDigit()
                .foregroundStyle(.textSecondary)
        }
    }

    static func fillPercent(attendance: Int, capacity: Int) -> Int {
        guard capacity > 0 else { return 0 }
        return Int((Double(attendance) / Double(capacity) * 100).rounded())
    }

    private func crowdAccessibilityLabel(_ attendance: Int) -> String {
        guard let capacity = summary.venueCapacity, capacity > 0 else {
            return "Attendance \(attendance.formatted())"
        }
        let percent = Self.fillPercent(attendance: attendance, capacity: capacity)
        return "Attendance \(attendance.formatted()) of \(capacity.formatted()) capacity, \(percent) percent full"
    }
}
