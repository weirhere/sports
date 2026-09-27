import SwiftUI

/// ESPN's Gamecast, as a card (2026-09-27): Down, Ball on and Drive across
/// the top, the drive drawn on a field beneath, and the last play under
/// that. Live games only — it is built from `drives.current`, which ESPN
/// drops the moment a game ends, so the card retires itself without a
/// second condition.
///
/// Nothing on it moves when the game does. The three columns are equal
/// thirds, so Ball on stays centered however wide the others get; the
/// touchdown header shares the columns' slot rather than replacing them;
/// and the last play always reserves two lines. A card polled every
/// second can't be allowed to jump.
struct LiveSituationCard: View {
    let summary: GameSummary
    let situation: GameSituation

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20

    private var offense: Team? { summary.team(withId: situation.possessionTeamId) }
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            Divider().overlay(Color.divider)
            if let field = situation.field {
                DriveField(field: field, away: summary.away, home: summary.home,
                           offenseLogoURL: offense?.logoURL,
                           playId: situation.lastPlayId)
                    // A new possession is a new field: the pin starts where
                    // the drive does rather than sliding over from where the
                    // last one ended.
                    .id(summary.currentDrive?.id)
                Divider().overlay(Color.divider)
            }
            lastPlay
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Header

    /// The columns and the result share one slot, both always laid out, so
    /// a touchdown trades one for the other without the field moving.
    private var header: some View {
        ZStack {
            columns.opacity(situation.result == nil ? 1 : 0)
            resultLine.opacity(situation.result == nil ? 0 : 1)
        }
    }

    @ViewBuilder
    private var columns: some View {
        if isStacked {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                column("Down", situation.downDistanceText, alignment: .leading)
                column("Ball on", situation.possessionText, alignment: .leading)
                column("Drive", situation.driveLine, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Equal thirds, not Spacers: Spacers share out what the values
            // leave over, so Ball on would slide as Down and Drive changed
            // width.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                column("Down", situation.downDistanceText, alignment: .leading)
                column("Ball on", situation.possessionText, alignment: .center)
                column("Drive", situation.driveLine, alignment: .trailing)
            }
        }
    }

    private func column(_ label: String, _ value: String?,
                        alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label.uppercased())
                .font(.rowMeta)
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
            Text(value ?? "—")
                .font(.teamName.monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private var resultLine: some View {
        HStack(spacing: Spacing.sm) {
            LogoImage(url: summary.team(withId: situation.resultTeamId)?.logoURL, placeholder: nil)
                .frame(width: logoSize, height: logoSize)
            Text((situation.result ?? "").uppercased())
                .font(.sectionHeaderProminent)
                .tracking(1.2)
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Last play

    private var lastPlay: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(lastPlayLabel.uppercased())
                    .font(.rowMeta)
                    .tracking(0.8)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                if let clock = situation.lastPlayClock {
                    Text(clock)
                        .font(.rowMeta.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
            }
            // Two lines are always held, so a one-line run followed by a
            // two-line touchdown doesn't change the card's height. A third
            // is allowed for the long ones — penalties, mostly — and is
            // the only way the card grows.
            ZStack(alignment: .topLeading) {
                Text(verbatim: "A\nA").hidden()
                Text(situation.lastPlayText ?? "")
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.teamName)
        }
    }

    /// "Last play · 2nd & 15 at WSU 48" — the situation the play started
    /// from, since the columns above say where it left things.
    private var lastPlayLabel: String {
        ["Last play", situation.lastPlayDownText].compactMap(\.self).joined(separator: " · ")
    }

    /// "Washington State ball, 2nd & 4, WSU 26, 1 play, 6 yds, Shotgun #20
    /// L.Pulalasi rush middle for 6 yards". After a score: "Washington
    /// State touchdown, …".
    /// Internal, not private, so the label shape is unit-testable.
    var accessibilitySummary: String {
        var parts: [String] = []
        if let result = situation.result {
            let scorer = summary.team(withId: situation.resultTeamId)?.location
            parts.append([scorer, result.lowercased()].compactMap(\.self).joined(separator: " "))
        } else {
            if let name = offense?.location { parts.append("\(name) ball") }
            if let down = situation.downDistanceText { parts.append(down) }
            if let spot = situation.possessionText { parts.append(spot) }
            if let line = situation.driveLine { parts.append(line) }
        }
        if let text = situation.lastPlayText { parts.append(text) }
        return parts.joined(separator: ", ")
    }
}
