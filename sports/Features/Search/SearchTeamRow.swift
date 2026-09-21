import SwiftUI

/// A team result on the search cover. A plain button, not a NavigationLink —
/// search navigates by dismissing and handing the Router a pending intent,
/// the same rails widget taps ride.
struct SearchTeamRow: View {
    let team: Team
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                // The conference under the name, where the nickname used to
                // sit beside it (Andy, 2026-09-21) — the player card's shape,
                // applied to teams. "Georgia / SEC" answers a different and
                // more useful question than "Georgia Bulldogs": the nickname
                // is decoration, the conference is where the team lives.
                VStack(alignment: .leading, spacing: 2) {
                    locationText
                    conferenceText
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            // Inside the label, like TeamFollowRow: flattening outside the
            // Button would strip its button trait from the merged element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
        }
        .buttonStyle(.plain)
    }

    /// VoiceOver keeps the disambiguation the league tag used to carry —
    /// "Miami, ACC" against "Miami, NFC East" — now that the tag is gone.
    var spokenLabel: String {
        "\(team.displayName ?? team.location), \(subtitle)"
    }

    /// The group a team plays in — the **division** for the NFL, where the
    /// directory files every team under its conference so `conferenceId`
    /// could only ever say AFC or NFC. The Jets are AFC East (Andy,
    /// 2026-09-21); "AFC" names a sixteenth of the league and answers
    /// nothing a fan asked.
    ///
    /// `FollowedTeamCard` has resolved it this way since 2026-09-09 and
    /// this row did not, which is how the same team read two ways on two
    /// screens. Same two calls, deliberately — a shared helper is the right
    /// answer the third time, not the second.
    ///
    /// Empty rather than "Other" when nothing is known: a row that says
    /// nothing beats one that says the wrong thing confidently.
    private var conferenceName: String {
        if team.league == .nfl,
           let division = Conference.division(forTeamId: team.id, in: .nfl) {
            let name = Conference.name(for: division, in: .nfl)
            return name == "Other" ? "" : name
        }
        let name = Conference.name(for: team.conferenceId, in: team.league)
        return name == "Other" ? "" : name
    }

    /// "NFL • NFC", "NCAAF • Big Ten", "NHL • Eastern" (Andy, 2026-09-21,
    /// league first).
    ///
    /// The league is here at all because the conference alone doesn't
    /// identify the sport — "Eastern" is the Lightning's conference and the
    /// Bucks', and on its own it was the least informative line on the
    /// screen beside a "Big Ten" and an "NFC". Reading league-first puts
    /// the four rows in a mixed list into four groups before the eye has to
    /// parse the specific one, and it sorts wide-to-narrow the way an
    /// address does. Falls back to the league alone rather than printing a
    /// trailing bullet when the conference is unknown.
    private var subtitle: String {
        let league = team.league.shortName
        return conferenceName.isEmpty ? league : "\(league) • \(conferenceName)"
    }

    private var conferenceText: some View {
        Text(subtitle)
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
    }

    /// The full name — "Tampa Bay Buccaneers", not "Tampa Bay" (Andy,
    /// 2026-09-21). The nickname left this row as a second column an hour
    /// earlier; it comes back inside the name, which is where it was always
    /// legible. `location` remains the fallback for a team ESPN gives no
    /// display name.
    private var locationText: some View {
        Text(team.displayName ?? team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
    }

}
