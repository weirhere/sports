import SwiftUI

/// The Venue card's body: where the game is played, what it's played on,
/// and how full the place was. Kickoff, the network and the forecast are
/// `KickoffInfoRows`' card; these are the ground's own facts.
///
/// The venue is the card's headline — name in ink, city beneath it in
/// meta gray (FotMob's treatment) — and the crowd numbers below it are
/// label/value pairs in the team-page cards' language. Attendance leads,
/// and where a capacity exists it becomes attendance's context and the
/// pair earns a fill meter in ink, never color.
///
/// **In practice there is never a capacity.** ESPN publishes none on any
/// surface we can reach — sampled live 2026-09-10 across all four
/// leagues, 100 core venue objects carried one 0 times, and the field is
/// not among the keys that resource ships. The rows below are written as
/// though it might arrive because the decode is still there and costs
/// nothing; what was removed is the per-venue *request* that went looking
/// for it. Don't re-add one without checking the payload first.
struct GameInfoRows: View {
    let summary: GameSummary

    /// Whether the card has anything to say about the ground itself —
    /// its gate, the `MatchupStandings.hasContent` precedent.
    static func hasVenueContent(_ summary: GameSummary) -> Bool {
        summary.venue != nil || summary.attendance != nil
            || summary.venueCapacity != nil || surface(of: summary) != nil
    }

    /// Grass or turf — and nothing at all for a sport played indoors on a
    /// floor or on ice, where ESPN still ships `grass: false` and we were
    /// rendering it as "Turf" on a hockey rink.
    static func surface(of summary: GameSummary) -> String? {
        let league = (summary.home ?? summary.away)?.team.league ?? .collegeFootball
        guard league.playsOnASurface else { return nil }
        return summary.grassSurface.map { $0 ? "Grass" : "Turf" }
    }

    private var surface: String? { Self.surface(of: summary) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            venueZone
        }
        .padding(.vertical, Spacing.xs)
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
            VenueHeadline(name: venue, city: summary.venueCity)
            if hasCrowdContent {
                zoneDivider
            }
        }
        crowdRows
    }

    /// Whether anything sits below the venue block — the divider's gate,
    /// so a card with a stadium and nothing else keeps its single row.
    private var hasCrowdContent: Bool {
        summary.attendance != nil || summary.venueCapacity != nil || surface != nil
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
