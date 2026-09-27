import SwiftUI

/// One move on the Trades tab: the team's mark, then ESPN's sentence word
/// for word, each move's verb in semibold (the brief's D2 and D8).
///
/// The NBA app's transactions list is the reference — a logo and a plain
/// sentence — because it is the one shape that matches what ESPN sends.
/// Monochrome: the verb's weight carries the kind of move, where FotMob and
/// the Premier League app spend green and red arrows the color budget has
/// no room for.
///
/// Not a link. ESPN names the player in prose and ships no athlete id, so
/// there is no page to push, and a row that looks tappable promises one.
struct RosterMoveRow: View {
    let move: RosterMove
    /// Off on a team page, where every row is the same team and the mark
    /// would repeat the header — FotMob trims its card the same way there.
    var showsTeamLogo = true

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if showsTeamLogo {
                LogoImage(url: move.team?.logoURL)
                    .frame(width: logoSize, height: logoSize)
            }
            Text(sentence)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The first line sits level with the mark's middle rather
                // than its top edge.
                .padding(.top, showsTeamLogo ? 4 : 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The wire copy with each verb in the emphasis weight. Built as an
    /// attributed string rather than concatenated `Text`s, so the ranges
    /// come straight from `RosterMove.verbRanges`.
    private var sentence: AttributedString {
        var attributed = AttributedString(move.text)
        for range in move.verbRanges {
            guard let verb = Range(range, in: attributed) else { continue }
            attributed[verb].font = .teamNameEmphasis
        }
        return attributed
    }

    /// "Charlotte Hornets. Acquired G Rob Dillingham…" — the team first,
    /// since on the league page the mark is the only thing naming it.
    private var accessibilitySummary: String {
        guard showsTeamLogo, let name = move.team?.displayName ?? move.team?.location else {
            return move.text
        }
        return "\(name). \(move.text)"
    }
}

#Preview {
    VStack(spacing: 0) {
        RosterMoveRow(move: RosterMove(
            id: "1", day: .now, team: nil,
            text: "Waived G DJ Armstrong and C Tre Carroll. Acquired Gs Buddy Hield, Ryan Nembhard "
                + "and cash considerations from Atlanta in exchange for F Dorian Finney-Smith."))
        RosterMoveRow(move: RosterMove(id: "2", day: .now, team: nil,
                                       text: "Re-signed F Dwight Powell."),
                      showsTeamLogo: false)
    }
    .cardSurface()
    .padding()
    .background(Color.bgRecessed)
}
