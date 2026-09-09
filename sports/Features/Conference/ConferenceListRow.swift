import SwiftUI

/// One conference in the Rankings list: mark, name, leader teaser, follow
/// star. The row navigates to the standings page; the star doesn't.
///
/// At accessibility text sizes the teaser drops under the name instead of
/// the two splitting one line into a pair of ellipses.
struct ConferenceListRow: View {
    let conference: ConferenceStandings

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let id = conference.conference {
                NavigationLink(value: ConferenceDestination(conference: id,
                                                            name: conference.name)) {
                    rowContent
                }
                // Not `.plain`: this row is also a card the Following list
                // lifts and drags, and `.plain` fires on any touch-up
                // still inside the row — which a whole-card drag never
                // leaves.
                .buttonStyle(SwipeSafeButtonStyle())
                ConferenceFollowStar(conference: id, conferenceName: conference.name)
            } else {
                // No id means no page and no follow — CFBD's unknown-name
                // fallback. The row still lists the conference.
                rowContent
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            ConferenceLogo(url: Conference.logoURL(for: conference.conference))
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    teaserText
                }
            } else {
                nameText
                teaserText
            }
            Spacer(minLength: Spacing.sm)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var nameText: some View {
        Text(conference.name)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(isStacked ? 2 : 1)
    }

    @ViewBuilder
    private var teaserText: some View {
        if let teaser {
            Text(teaser)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    /// The whole league standing as one table shows no teaser at all
    /// (Andy, 2026-09-09). Its "leader" is only the best record in the
    /// sport, which is not the question a league row is asked — and the
    /// number it was showing was an *in-group* record on a row that spans
    /// every group, so the NFL's read as a conference record and the
    /// NBA's as a 41-11 that matched no column on the page it opens.
    private var isLeagueWide: Bool {
        Conference.tier(for: conference.id, in: conference.league) == .league
    }

    /// "Ole Miss · 7-1" — the current leader, only once records exist.
    private var teaser: String? {
        guard !isLeagueWide,
              let leader = conference.leader,
              let record = leaderRecord(leader) else { return nil }
        return "\(leader.team.location) · \(record)"
    }

    /// The record a teaser shows: the in-group one where the league keeps
    /// it, which is the number a table is sorted by in football and
    /// basketball — and otherwise the overall one, because the NHL ships
    /// no conference record at all and every hockey row would sit here
    /// bare while the ones above it read fine.
    private func leaderRecord(_ leader: ConferenceStanding) -> String? {
        leader.conferenceRecord ?? leader.displayRecord
    }

    /// "SEC, led by Ole Miss at 7 and 1" — or just the name preseason,
    /// and just the name for a whole-league row, which teases nothing.
    var accessibilitySummary: String {
        guard !isLeagueWide,
              let leader = conference.leader,
              let record = leaderRecord(leader) else { return conference.name }
        let spoken = record.replacingOccurrences(of: "-", with: " and ")
        return "\(conference.name), led by \(leader.team.location) at \(spoken)"
    }
}
