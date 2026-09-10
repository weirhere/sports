import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

/// The Live Activity card: one chassis, one swappable centre slot.
///
/// The two identity groups never change between states — only what sits
/// between them, and whether a record or a score is showing. Drawn to the
/// locked design (Figma `↳ Live Activities` → Design · Live Activity v1,
/// direction A), in the widget's own vocabulary: 20/24pt marks, `chip`
/// abbreviations, `metaMedium` records, the 4pt spacing scale.
struct GameActivityCard: View {
    let attributes: GameActivityAttributes
    let state: GameActivityAttributes.ContentState
    var isStale = false

    /// Every state is the same height, so the card never grows or shrinks
    /// as the game moves through them. iOS animates a height change, which
    /// makes a mid-drive reflow of the lock screen worse, not better.
    private static let height: CGFloat = 64

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ActivityTeamSide(side: attributes.away,
                             score: state.awayScore,
                             showsScore: state.showsScores,
                             showsRecord: state.phase == .pre,
                             muted: isMuted(state.awayScore, against: state.homeScore),
                             mirrored: false)
            Spacer(minLength: Spacing.sm)
            centre
            Spacer(minLength: Spacing.sm)
            ActivityTeamSide(side: attributes.home,
                             score: state.homeScore,
                             showsScore: state.showsScores,
                             showsRecord: state.phase == .pre,
                             muted: isMuted(state.homeScore, against: state.awayScore),
                             mirrored: true)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var centre: some View {
        VStack(spacing: 2) {
            Text(state.headline)
                .font(state.phase == .pre ? .activityHero : .score)
                .foregroundStyle(headlineColor)
                .lineLimit(1)
                .fixedSize()
            if let detail {
                Text(detail)
                    .font(.metaMedium)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    /// Green belongs to a clock we can vouch for. Once the card is stale we
    /// no longer can, so the accent goes and an as-of line takes the second
    /// row — the card stops presenting an old number as current rather than
    /// looking authoritative while lying.
    private var headlineColor: Color {
        guard state.phase.isLive, !isStale else { return .textPrimary }
        return .liveAccent
    }

    private var detail: String? {
        if isStale {
            return "as of \(state.asOf.formatted(.dateTime.hour().minute()))"
        }
        return state.detail
    }

    /// The losing side's number drops to secondary ink once the game is
    /// over — the detail header's combined score line, on a smaller card.
    /// Never during play: a lead is not a result.
    private func isMuted(_ mine: Int?, against theirs: Int?) -> Bool {
        guard state.phase == .final, let mine, let theirs else { return false }
        return mine < theirs
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if state.showsScores {
            parts.append("\(attributes.away.abbreviation) \(state.awayScore ?? 0)")
            parts.append("\(attributes.home.abbreviation) \(state.homeScore ?? 0)")
        } else {
            parts.append("\(attributes.away.abbreviation) at \(attributes.home.abbreviation)")
        }
        parts.append(state.headline)
        if let detail { parts.append(detail) }
        return parts.joined(separator: ", ")
    }
}

/// One side of the chassis: mark outboard, number inboard, so the eye lands
/// on the digits and resolves whose they are on the way back out.
struct ActivityTeamSide: View {
    @Environment(\.colorScheme) private var colorScheme
    let side: GameActivityAttributes.Side
    let score: Int?
    let showsScore: Bool
    /// Records are pre-game only — the `GameRow` rule (2026-08-25). Once
    /// there is a score, the score is what the column is for.
    let showsRecord: Bool
    let muted: Bool
    let mirrored: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if mirrored {
                scoreText
                identity
                logo
            } else {
                logo
                identity
                scoreText
            }
        }
    }

    private var identity: some View {
        VStack(alignment: mirrored ? .trailing : .leading, spacing: 1) {
            Text(side.abbreviation)
                .font(.chip)
                .foregroundStyle(muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
            if showsRecord, let record = side.record {
                Text(record)
                    .font(.metaMedium)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var scoreText: some View {
        if showsScore {
            Text(score.map(String.init) ?? "–")
                .font(.activityHero)
                .foregroundStyle(muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// Bytes come off the App Group cache synchronously — an activity view
    /// renders once, with no `.task` and no `AsyncImage`, exactly like a
    /// widget view. A cold cache degrades to the placeholder disc rather
    /// than to a broken image.
    @ViewBuilder
    private var logo: some View {
        let url = colorScheme == .dark ? (side.darkLogo ?? side.logo) : side.logo
        if let image = WidgetLogoFetcher.cachedLogo(for: url)
            ?? WidgetLogoFetcher.cachedLogo(for: side.logo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        } else {
            Circle()
                .fill(Color.bgElevated)
                .frame(width: 24, height: 24)
        }
    }
}

/// The compact island: crest and score per side, and nothing invented.
/// This is the container a fan glances at for the number, so it shows the
/// number — a strict subset of the big card, never something different.
struct ActivityCompactSide: View {
    @Environment(\.colorScheme) private var colorScheme
    let side: GameActivityAttributes.Side
    let score: Int?
    let showsScore: Bool
    let mirrored: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if mirrored {
                if showsScore { scoreText }
                logo
            } else {
                logo
                if showsScore { scoreText }
            }
        }
    }

    private var scoreText: some View {
        Text(score.map(String.init) ?? "–")
            .font(.rowNameEmphasis)
            .foregroundStyle(.textPrimary)
            .monospacedDigit()
    }

    @ViewBuilder
    private var logo: some View {
        let url = colorScheme == .dark ? (side.darkLogo ?? side.logo) : side.logo
        if let image = WidgetLogoFetcher.cachedLogo(for: url)
            ?? WidgetLogoFetcher.cachedLogo(for: side.logo) {
            Image(uiImage: image).resizable().scaledToFit().frame(width: 18, height: 18)
        } else {
            Circle().fill(Color.bgElevated).frame(width: 18, height: 18)
        }
    }
}
#endif
