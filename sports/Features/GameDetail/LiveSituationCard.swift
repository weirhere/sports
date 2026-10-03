import SwiftUI

/// ESPN's Gamecast, as a card (2026-09-27), in every league: three
/// labeled columns across the top, the surface beneath them — football's
/// field, basketball's court, hockey's rink — and the last play under
/// that. Live games only (D1). Football's is built from `drives.current`,
/// which ESPN drops the moment a game ends; the court and rink are gated
/// on the game being live by the screen.
///
/// The card doesn't know which league it's showing: it prints a
/// `GamecastContent`, and each league builds one. That's what keeps the
/// three from drifting apart.
///
/// Nothing on it moves when the game does. The three columns are equal
/// thirds, so the middle one stays centered however wide the others get;
/// the result line shares the columns' slot rather than replacing them;
/// and the last play always reserves two lines. A card polled every
/// second can't be allowed to jump.
struct LiveSituationCard: View {
    let content: GamecastContent
    let surface: AnyView?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20

    init(content: GamecastContent, surface: AnyView?) {
        self.content = content
        self.surface = surface
    }

    /// Football's card: the drive on the field.
    init(summary: GameSummary, situation: GameSituation) {
        let offense = summary.team(withId: situation.possessionTeamId)
        self.init(
            content: GamecastContent(situation: situation, summary: summary),
            surface: situation.field.map { field in
                AnyView(DriveField(field: field, away: summary.away, home: summary.home,
                                   offenseLogoURL: offense?.logoURL,
                                   playId: situation.lastPlayId)
                    // A new possession is a new field: the pin starts where
                    // the drive does rather than sliding over from where the
                    // last one ended.
                    .id(summary.currentDrive?.id))
            }
        )
    }

    /// Basketball's and hockey's card: this period's shots on the court or
    /// rink, keyed by period so the surface clears at each break (D9).
    init(summary: GameSummary, content: GamecastContent, map: ShotMap) {
        let latestTeam = map.latest.map { $0.side == .away ? summary.away : summary.home }
        let logo = latestTeam??.team.logoURL
        let surface: AnyView = switch map.surface {
        case .court:
            AnyView(CourtSurface(map: map, away: summary.away, home: summary.home,
                                 latestLogoURL: logo).id(map.period))
        case .rink:
            AnyView(RinkSurface(map: map, away: summary.away, home: summary.home,
                                latestLogoURL: logo).id(map.period))
        }
        self.init(content: content, surface: surface)
    }

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            Divider().overlay(Color.divider)
            if let surface {
                surface
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

    /// Internal, not private, so the label shape is unit-testable.
    var accessibilitySummary: String { content.accessibilitySummary }

    // MARK: - Header

    /// The columns and the result share one slot, both always laid out, so
    /// a touchdown trades one for the other without the field moving.
    private var header: some View {
        ZStack {
            columns.opacity(content.result == nil ? 1 : 0)
            resultLine.opacity(content.result == nil ? 0 : 1)
        }
    }

    @ViewBuilder
    private var columns: some View {
        if isStacked {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(content.slots.enumerated()), id: \.offset) { _, slot in
                    column(slot, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Equal thirds, not Spacers: Spacers share out what the values
            // leave over, so the middle column would slide as the outer two
            // changed width.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(Array(content.slots.enumerated()), id: \.offset) { index, slot in
                    column(slot, alignment: index == 0 ? .leading
                           : index == content.slots.count - 1 ? .trailing : .center)
                }
            }
        }
    }

    private func column(_ slot: GamecastSlot, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(slot.label.uppercased())
                .font(.rowMeta)
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
            Text(slot.value ?? "—")
                .font(.teamName.monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private var resultLine: some View {
        HStack(spacing: Spacing.sm) {
            LogoImage(url: content.resultTeam?.logoURL, placeholder: nil)
                .frame(width: logoSize, height: logoSize)
            Text((content.result ?? "").uppercased())
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
                Text(content.lastPlayLabel.uppercased())
                    .font(.rowMeta)
                    .tracking(0.8)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                if let clock = content.lastPlayClock {
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
                Text(content.lastPlayText ?? "")
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.teamName)
        }
    }
}
