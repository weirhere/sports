import SwiftUI

/// The number at a stat row's trailing edge. The leader's sits in a filled
/// capsule — FotMob's blue pill made monochrome, ink rather than color, so
/// the budget is unchanged (2026-10-25). Shared by the team and player
/// rows so the two tabs mark a leader the same way.
struct StatValueLabel: View {
    let value: String
    var isLeader = false
    /// A followed team's row reads in weight, as everywhere else.
    var isEmphasized = false

    var body: some View {
        let text = Text(value)
            .font((isLeader || isEmphasized ? Font.teamNameEmphasis : .teamName).monospacedDigit())
            .lineLimit(1)
        if isLeader {
            text
                .foregroundStyle(Color.bgCard)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.textPrimary))
        } else {
            text
                .foregroundStyle(.textPrimary)
                // The capsule's own inset, so the leader's number and the
                // rows under it share a trailing edge.
                .padding(.horizontal, Spacing.sm)
        }
    }
}
