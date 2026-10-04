import SwiftUI

/// The Roster tab's card stack: the head coach (a link to their page since
/// E27), then a card per position
/// group in the payload's own order, each group's players in jersey order.
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
    /// The team the roster belongs to — a player page carries the crest and
    /// name of the team it was reached through, and a roster belongs to one.
    let team: Team

    /// Optional so a host that never injected it (a preview) draws the
    /// head coach alone rather than crashing.
    @Environment(CoachStaffStore.self) private var coachStaff: CoachStaffStore?

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

    /// The head coach — a link to their page when ESPN sent an id (E27,
    /// 2026-09-27) — then the coordinators and quarterbacks coach from
    /// `coaches.json` (2026-10-03), in its order: offense, defense, special
    /// teams, assistant head coach, quarterbacks.
    private func coachCard(_ coach: RosterCoach) -> some View {
        let staff = coachStaff?.staff(for: team) ?? []
        return VStack(spacing: 0) {
            CardHeader(title: staff.isEmpty ? "Coach" : "Coaching staff")
            if let id = coach.id {
                NavigationLink(value: CoachIdentity(coachId: id, name: coach.name,
                                                    league: league, team: team)) {
                    headCoachRow(coach, isLink: true)
                }
                .buttonStyle(.plain)
            } else {
                headCoachRow(coach, isLink: false)
            }
            ForEach(staff, id: \.self) { member in
                Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                RosterCoachRow(name: member.name, role: member.role)
            }
        }
        .padding(.bottom, staff.isEmpty ? 0 : Spacing.xs)
        .cardSurface()
    }

    private func headCoachRow(_ coach: RosterCoach, isLink: Bool) -> some View {
        RosterCoachRow(name: coach.name, role: "Head coach",
                       headshotURL: coach.headshotURL(in: league), isLink: isLink)
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
                    // `.plain` rather than `SwipeSafeButtonStyle`, matching
                    // `TeamScheduleSection` in the same swipeable pane: the
                    // 2026-09-06 stray-push was the Scores day swipe's.
                    NavigationLink(value: PlayerIdentity(player: player,
                                                         team: team,
                                                         league: league)) {
                        RosterRow(player: player, league: league, isLink: true)
                    }
                    .buttonStyle(.plain)
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
