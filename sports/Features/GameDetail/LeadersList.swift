import SwiftUI

/// Passing / rushing / receiving leaders, FotMob-style: each category is a
/// centered label with the two sides' leaders anchored to their header
/// sides — the away player left-aligned on the left, the home player
/// right-aligned on the right, headshots on the outside edges.
struct LeadersList: View {
    let summary: GameSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // The card's CardHeader names the section now; this view is just
        // the category groups.
        VStack(spacing: Spacing.md) {
            ForEach(summary.leaders) { category in
                categoryGroup(category)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private func categoryGroup(_ category: LeaderCategory) -> some View {
        VStack(alignment: isStacked ? .leading : .center, spacing: Spacing.xs) {
            Text(category.label.uppercased())
                .font(.meta)
                .foregroundStyle(.textSecondary)
            if isStacked {
                // Side-by-side halves can't hold accessibility type; the
                // sides stack instead, each labeled by its abbreviation
                // since alignment no longer says whose player it is.
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let away = category.away {
                        stackedRow(away, team: summary.away?.team)
                    }
                    if let home = category.home {
                        stackedRow(home, team: summary.home?.team)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: Spacing.md) {
                    sideSlot(category.away, team: summary.away?.team, side: .away)
                    sideSlot(category.home, team: summary.home?.team, side: .home)
                }
            }
        }
    }

    private enum Side {
        case away, home
    }

    /// Half the row, claimed even when a side has no leader so the other
    /// side stays anchored to its edge.
    @ViewBuilder
    private func sideSlot(_ leader: LeaderCategory.Leader?, team: Team?, side: Side) -> some View {
        Group {
            if let leader {
                sideView(leader, team: team, side: side)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: side == .away ? .leading : .trailing)
    }

    private func sideView(_ leader: LeaderCategory.Leader, team: Team?, side: Side) -> some View {
        HStack(spacing: Spacing.sm) {
            if side == .away { headshot(leader, team: team, side: side) }
            VStack(alignment: side == .away ? .leading : .trailing, spacing: 2) {
                Text(leader.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    // Half-width columns are tight; hyphenated last names
                    // ("Malone-Woods") wrap rather than truncate.
                    .lineLimit(2)
                    .multilineTextAlignment(side == .away ? .leading : .trailing)
                Text(leader.statLine)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(side == .away ? .leading : .trailing)
            }
            if side == .home { headshot(leader, team: team, side: side) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(leader, team: team))
    }

    /// The player photo cropped into a quiet disc, wearing a small team
    /// mark on its outer corner — the abbreviation column's replacement
    /// now that the sides carry the team identity.
    private func headshot(_ leader: LeaderCategory.Leader, team: Team?, side: Side) -> some View {
        LogoImage(url: leader.headshotURL, placeholder: nil, contentMode: .fill)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
            .overlay(alignment: side == .away ? .bottomLeading : .bottomTrailing) {
                if let logoURL = team?.logoURL {
                    LogoImage(url: logoURL, placeholder: nil)
                        .frame(width: 15, height: 15)
                }
            }
    }

    private func stackedRow(_ leader: LeaderCategory.Leader, team: Team?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.sm) {
                Text(team?.abbreviation ?? "")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                Text(leader.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            Text(leader.statLine)
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(leader, team: team))
    }

    /// Internal for AccessibilityLabelTests.
    func accessibilityLabel(_ leader: LeaderCategory.Leader, team: Team?) -> String {
        ([team?.location, leader.name, leader.statLine] as [String?])
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
