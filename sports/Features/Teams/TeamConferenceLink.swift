import SwiftUI

/// The team header's conference line: conference mark + name, with the
/// season's placement folded in ("Big Ten · 1st") when a standing exists —
/// so the conference stays reachable offseason, on past seasons, and from
/// entry paths that pushed no id. Tapping shows the full conference
/// standings. An unknown/"Other" conference renders the standing as plain
/// text, or nothing (there is no page for Other).
struct TeamConferenceLink: View {
    let conferenceId: Int?
    let standing: String?   // caller pre-filters the 0-0 rule

    /// "1st in Big Ten" → "1st". A standing that doesn't match ESPN's
    /// "<placement> in <conference>" shape drops the placement rather than
    /// garbling the line.
    private var placement: String? {
        guard let standing else { return nil }
        let parts = standing.components(separatedBy: " in ")
        guard parts.count == 2, let ordinal = parts.first, !ordinal.isEmpty else { return nil }
        return ordinal
    }

    var body: some View {
        if let conferenceId, Conference.tier(for: conferenceId) != .other {
            NavigationLink(value: ConferenceDestination(
                conferenceId: conferenceId,
                name: Conference.name(for: conferenceId)
            )) {
                HStack(spacing: Spacing.xs) {
                    ConferenceLogo(url: Conference.logoURL(for: conferenceId))
                        .accessibilityHidden(true)
                    Text(placement.map { "\(Conference.name(for: conferenceId)) · \($0)" }
                        ?? Conference.name(for: conferenceId))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.meta)
                .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("View conference standings")
        } else if let standing {
            Text(standing)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
    }
}
