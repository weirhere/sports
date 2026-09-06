import SwiftUI

/// The poll table's column captions — # / TEAM / OVR / MOV — mirroring
/// `StandingsColumnCaptions` so the Top 25 reads as the same kind of table
/// as every conference's standings (Andy, 2026-09-05). The last column is
/// the one thing a poll has that a standings table doesn't.
///
/// Visual-only: rows speak themselves as sentences, so VoiceOver skips it.
struct RankColumnCaptions: View {
    // Mirror RankRow's column metrics so captions align with the numbers
    // beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var movementWidth: CGFloat = 40

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text("#")
                .frame(minWidth: rankWidth, alignment: .trailing)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("OVR")
                .frame(minWidth: recordWidth, alignment: .trailing)
            Text("MOV")
                .frame(minWidth: movementWidth, alignment: .trailing)
        }
        .font(.meta)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Spacing.lg)
        // Breathing room off the card's top edge, the standings captions'
        // spacing.
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .accessibilityHidden(true)
    }
}
