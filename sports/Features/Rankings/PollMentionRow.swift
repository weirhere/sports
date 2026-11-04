import SwiftUI

/// A team the poll names outside its top 25: still drawing votes, or ranked
/// last week and not this one (COR-58). `RankRow`'s columns minus the two a
/// mention doesn't have: no place (ESPN ships `current: 0`, and there is no
/// 26th; the gutter stays, empty, so logo and name line up with the Top 25
/// card above) and no record (ESPN's is a "0-0" placeholder on every
/// mention). The last column, under the Top 25's MOV, holds the one number
/// the mention has.
///
/// Monochrome throughout: a drop-out's old rank is history, not a move, so
/// it never borrows the red that `RankRow` spends on falling.
struct PollMentionRow: View {
    enum Kind {
        /// "Receiving votes" — the last column is the poll points.
        case votes
        /// "Dropped out" — the last column is last week's rank.
        case droppedOut
    }

    let mention: PollMention
    let kind: Kind

    @Environment(FollowingStore.self) private var following
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var valueWidth: CGFloat = 40

    var body: some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: rankWidth, height: 1)
            LogoImage(url: mention.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(mention.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            valueLabel
                .frame(minWidth: valueWidth, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                following.toggle(mention.team)
            } label: {
                Label(followActionTitle, systemImage: following.isFollowing(mention.team) ? "star.slash" : "star")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction(named: followActionTitle) {
            following.toggle(mention.team)
        }
    }

    private var valueLabel: some View {
        Text(valueText ?? "–")
            .font(kind == .votes ? .metaEmphasis.monospacedDigit() : .meta.monospacedDigit())
            .foregroundStyle(kind == .votes && valueText != nil ? .textPrimary : .textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// Points as a whole number (ESPN sends them as a double), or the rank
    /// fallen from. Nil when the payload left it out.
    private var valueText: String? {
        switch kind {
        case .votes:
            mention.points.map { String(Int($0.rounded())) }
        case .droppedOut:
            mention.previousRank.flatMap { $0 > 0 ? String($0) : nil }
        }
    }

    private var followActionTitle: String {
        following.isFollowing(mention.team) ? "Unfollow \(mention.team.location)" : "Follow \(mention.team.location)"
    }

    /// "Arizona, 54 points" / "Arizona, ranked 21 last week". Internal so
    /// the label shape is unit-testable.
    var accessibilitySummary: String {
        var parts = [mention.team.location]
        if let value = valueText {
            switch kind {
            case .votes: parts.append(value == "1" ? "1 point" : "\(value) points")
            case .droppedOut: parts.append("ranked \(value) last week")
            }
        }
        return parts.joined(separator: ", ")
    }
}
