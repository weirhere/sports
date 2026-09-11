import SwiftUI

/// The Roster tab's card stack: the head coach, then a card per position
/// group in the payload's own order.
///
/// FotMob's squad screen is the reference — a card per group, its header
/// carrying one right-aligned metric caption, rows of number · photo · name ·
/// metric. The parts are the app's existing table language (`CardHeader`, a
/// captions row, inset dividers), so a roster reads like a standings table
/// rather than a second dialect.
///
/// The grouping is always ESPN's, never ours: football's six squads, hockey's
/// five position names, and — for basketball, which ships no grouping at all —
/// one card. Deriving guards and forwards from each athlete's position would
/// be inventing a structure the payload doesn't have.
struct RosterList: View {
    let roster: TeamRoster
    let league: League

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let coach = roster.coach {
                coachCard(coach)
            }
            ForEach(roster.groups) { group in
                groupCard(group)
            }
        }
    }

    private func coachCard(_ coach: RosterCoach) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: "Coach")
            HStack(spacing: Spacing.md) {
                Text(coach.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                Text("Head coach")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .accessibilityElement(children: .combine)
        }
        .cardSurface()
    }

    private func groupCard(_ group: RosterGroup) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: group.name)
            RosterColumnCaptions(league: league)
            // Lazy on purpose: a college football offense is 50 players, and
            // every row owns a headshot request. In a plain VStack they all
            // fire the moment the tab opens, whether or not anyone scrolls
            // that far. Nested inside the page's ScrollView, this materializes
            // rows against the visible bounds instead.
            LazyVStack(spacing: 0) {
                ForEach(Array(group.players.enumerated()), id: \.element.id) { index, player in
                    RosterRow(player: player, league: league)
                    if index < group.players.count - 1 {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}

/// The roster table's column captions — `#` / `PLAYER` / the league's own
/// metric — `StandingsColumnCaptions`' sibling, and aligned to `RosterRow`'s
/// columns the same way: by mirroring its `@ScaledMetric` widths.
///
/// Visual-only: rows speak themselves as sentences, so VoiceOver skips it.
struct RosterColumnCaptions: View {
    let league: League

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var jerseyWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        // At accessibility sizes the row folds its metric onto a labeled
        // line, so the captions would caption nothing.
        if !dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: Spacing.md) {
                Text("#")
                    .frame(minWidth: jerseyWidth, alignment: .trailing)
                Text("PLAYER")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(league.rosterMetric.caption)
                    .frame(minWidth: league.rosterMetric.width * scale, alignment: .trailing)
            }
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, Spacing.lg)
            // Breathing room off the card header's hairline above.
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .accessibilityHidden(true)
        }
    }
}
