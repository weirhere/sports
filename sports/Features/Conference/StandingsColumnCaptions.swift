import SwiftUI

/// The standings tables' column captions — # / TEAM / CONF / OVR —
/// shared by the full tables (StandingsList) and the game page's matchup
/// slice so the two record columns always read the same way.
/// Visual-only: rows speak themselves as sentences, so VoiceOver skips it.
struct StandingsColumnCaptions: View {
    // Mirror ConferenceStandingRow's column metrics so captions align
    // with the numbers beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text("#")
                .frame(minWidth: positionWidth, alignment: .trailing)
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CONF")
                .frame(minWidth: recordWidth, alignment: .trailing)
            Text("OVR")
                .frame(minWidth: recordWidth, alignment: .trailing)
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
