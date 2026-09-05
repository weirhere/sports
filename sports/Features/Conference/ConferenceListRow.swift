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
                .buttonStyle(.plain)
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

    /// "Ole Miss · 7-1" — the current leader, only once records exist.
    private var teaser: String? {
        guard let leader = conference.leader,
              let record = leader.conferenceRecord else { return nil }
        return "\(leader.team.location) · \(record)"
    }

    /// "SEC, led by Ole Miss at 7 and 1" — or just the name preseason.
    var accessibilitySummary: String {
        guard let leader = conference.leader,
              let record = leader.conferenceRecord else { return conference.name }
        let spoken = record.replacingOccurrences(of: "-", with: " and ")
        return "\(conference.name), led by \(leader.team.location) at \(spoken)"
    }
}
