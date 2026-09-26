import SwiftUI

/// The tally a collapsed section header carries beside its chevron (Andy,
/// 2026-09-25). Quiet gray with the section's game count; once any of those
/// games is being played it turns live and reads "live/total", in the Live
/// chip's own language — the accent on its tint, inside its hairline — so a
/// folded section still says there's something happening inside it.
struct SectionCountBadge: View {
    let live: Int
    let total: Int

    private var isLive: Bool { live > 0 }

    var body: some View {
        Text(isLive ? "\(live)/\(total)" : "\(total)")
            .font(.metaEmphasis)
            .monospacedDigit()
            .foregroundStyle(isLive ? Color.liveAccent : Color.textSecondary)
            .padding(.horizontal, 6)
            .frame(minWidth: 18, minHeight: 18)
            .background(
                Capsule()
                    .fill(isLive ? Color.liveTint : Color.divider)
                    .overlay(
                        Capsule().strokeBorder(isLive ? Color.liveEdge : Color.clear,
                                               lineWidth: 1)
                    )
            )
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        SectionCountBadge(live: 0, total: 3)
        SectionCountBadge(live: 2, total: 3)
        SectionCountBadge(live: 10, total: 12)
    }
    .padding()
    .background(Color.bgHeader)
}
