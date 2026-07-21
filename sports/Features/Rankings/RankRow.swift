import SwiftUI

/// One ranked team: rank, logo, name, first-place votes, record, movement.
/// Movement is the one place besides live state that spends color: green up,
/// red down. Arrows carry the meaning too, so color is never the only signal.
struct RankRow: View {
    let ranked: RankedTeam

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 22

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(ranked.current)")
                .font(.score)
                .foregroundStyle(.textPrimary)
                .frame(width: 26, alignment: .trailing)
            LogoImage(url: ranked.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(ranked.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let votes = ranked.firstPlaceVotes, votes > 0 {
                Text("(\(votes))")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            if let record = ranked.record {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            movementLabel
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// One spoken sentence: "Number 3, Georgia, 5 and 0, up 2".
    /// Internal, not private, so the label shape is unit-testable.
    var accessibilitySummary: String {
        var parts = ["Number \(ranked.current)", ranked.team.location]
        if let votes = ranked.firstPlaceVotes, votes > 0 {
            parts.append("\(votes) first-place votes")
        }
        if let record = ranked.record {
            parts.append(record.replacingOccurrences(of: "-", with: " and "))
        }
        switch ranked.movement {
        case .some(let delta) where delta > 0: parts.append("up \(delta)")
        case .some(let delta) where delta < 0: parts.append("down \(-delta)")
        case .some: parts.append("no change")
        case nil: parts.append("newly ranked")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var movementLabel: some View {
        switch ranked.movement {
        case .some(let delta) where delta > 0:
            Text("▲ \(delta)")
                .font(.metaEmphasis)
                .foregroundStyle(.rankUp)
        case .some(let delta) where delta < 0:
            Text("▼ \(-delta)")
                .font(.metaEmphasis)
                .foregroundStyle(.rankDown)
        case .some:
            Text("–")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        case nil:
            Text("NEW")
                .font(.metaEmphasis)
                .foregroundStyle(.textSecondary)
        }
    }
}
