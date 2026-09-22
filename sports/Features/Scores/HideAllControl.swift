import SwiftUI

/// The boundary between the sections that are yours — Following, and every
/// conference/league/poll you follow — and the rest of the day's slate
/// below them (FotMob parity, Andy 2026-09-22). One tap collapses that
/// whole remaining stack to this one line, or brings it back; it never
/// touches Following, a followed table, or any accordion's own expanded
/// state, which is what makes it safe to leave on across days.
///
/// Only ever placed where there's an actual boundary to draw — see
/// `ScoresScreen.scoresRows(for:hideOthers:)`, which omits it entirely when
/// you follow nobody or when what you follow already covers the whole day.
struct HideAllControl: View {
    let otherCount: Int
    let isHidden: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.sm) {
                    Text(isHidden ? "Show all" : "Hide all")
                        .font(.chipEmphasis)
                    Image(systemName: isHidden ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm + 2)
                .background(Capsule().fill(Color.bgElevated))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHidden ? "Show all sections" : "Hide all sections")
            .accessibilityValue(isHidden ? "\(otherCount) hidden" : "")
            .accessibilityIdentifier("scores-hide-all-control")
            // Named so a hidden stack never reads as gone for good — the
            // count is the whole reason this isn't just an empty tap
            // target (FotMob's "22 other competitions play today"). The
            // button's own accessibilityValue already says the count, so
            // this stays out of VoiceOver rather than repeating it.
            if isHidden {
                Text("\(otherCount) other section\(otherCount == 1 ? "" : "s")")
                    .font(.meta)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HideAllControl(otherCount: 6, isHidden: false, onToggle: {})
        HideAllControl(otherCount: 6, isHidden: true, onToggle: {})
    }
    .padding()
    .background(Color.bgRecessed)
}
