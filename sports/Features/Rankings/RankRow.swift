import SwiftUI

/// One ranked team: rank, logo, name, first-place votes, record, movement.
/// Movement is the one place besides live state that spends color: green up,
/// red down. Arrows carry the meaning too, so color is never the only signal.
///
/// At accessibility text sizes the meta (votes, record, movement) drops to a
/// second line instead of squeezing the name down to an ellipsis.
struct RankRow: View {
    let ranked: RankedTeam

    @Environment(FollowingStore.self) private var following
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var rankWidth: CGFloat = 26
    @ScaledMetric(relativeTo: .caption) private var movementWidth: CGFloat = 40

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isStacked { stackedBody } else { compactBody }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .contextMenu {
            Button {
                following.toggle(ranked.team.id)
            } label: {
                Label(followActionTitle, systemImage: following.isFollowing(ranked.team.id) ? "star.slash" : "star")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction(named: followActionTitle) {
            following.toggle(ranked.team.id)
        }
    }

    private var compactBody: some View {
        HStack(spacing: Spacing.sm) {
            rankNumber
            teamLogo
            teamName
            votesLabel
            Spacer()
            recordLabel
            movementLabel
                .frame(minWidth: movementWidth, alignment: .trailing)
        }
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                rankNumber
                teamLogo
                teamName
                Spacer(minLength: 0)
            }
            HStack(spacing: Spacing.sm) {
                votesLabel
                recordLabel
                Spacer(minLength: Spacing.sm)
                movementLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Parts

    private var rankNumber: some View {
        Text("\(ranked.current)")
            .font(.score)
            .foregroundStyle(.textPrimary)
            // The compact list right-aligns ranks into a gutter so 1 and 25
            // share an edge. Stacked rows have no gutter to align to — the
            // meta line below starts flush left, so the rank does too.
            .frame(minWidth: isStacked ? nil : rankWidth, alignment: .trailing)
    }

    private var teamLogo: some View {
        LogoImage(url: ranked.team.logoURL)
            .frame(width: logoSize, height: logoSize)
    }

    private var teamName: some View {
        Text(ranked.team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            // The stacked row owns its line, so a long name wraps rather
            // than truncating.
            .lineLimit(isStacked ? 2 : 1)
    }

    @ViewBuilder
    private var votesLabel: some View {
        if let votes = ranked.firstPlaceVotes, votes > 0 {
            Text("(\(votes))")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var recordLabel: some View {
        if let record = ranked.record {
            Text(record)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    private var followActionTitle: String {
        following.isFollowing(ranked.team.id) ? "Unfollow \(ranked.team.location)" : "Follow \(ranked.team.location)"
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
        // "NEW" is short but wider than the column at large text sizes —
        // without this it wraps to "NE" over "W".
        Group {
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
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
