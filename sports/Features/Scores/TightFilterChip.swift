import SwiftUI

/// Tap to show only tight games: live, and late and close, or with the
/// underdog in front (`GameCloseness`). Coard Miller, 2026-09-24: "if it's
/// an upset or a closer game than the spread suggests, it might be worth
/// watching."
///
/// Named **Tight**, not "Close": in a header, "Close" reads as the button
/// that dismisses something (Andy, 2026-09-24).
///
/// Live's sibling in the header's grouped capsule, and it follows Live's
/// rules: it narrows today only, and a tap off today is a trip home. Active,
/// it wears **ink** rather than the live accent. Live already spends the
/// green in this capsule, and one header doesn't get it twice.
struct TightFilterChip: View {
    let tightOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text("Tight")
                .font(.chipEmphasis)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.md + 2)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(tightOnly ? Color.textPrimary.opacity(0.1) : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                tightOnly ? Color.textPrimary.opacity(0.35) : Color.clear,
                                lineWidth: 1)
                        )
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: tightOnly)
        .accessibilityLabel("Tight games only")
        .accessibilityHint("Live games that are close late, or where the underdog leads")
        .accessibilityAddTraits(tightOnly ? .isSelected : [])
        .accessibilityIdentifier("scores-tight-chip")
    }
}
