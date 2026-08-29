import SwiftUI

/// Horizontal week selector, driven entirely by ESPN's parsed calendar.
/// Past weeks sit left, future right; postseason slots use names.
struct WeekStrip: View {
    let weeks: [WeekSlot]
    let selectedId: String?
    let onSelect: (WeekSlot) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(weeks) { week in
                        chip(for: week)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .onAppear {
                if let selectedId {
                    proxy.scrollTo(selectedId, anchor: .center)
                }
            }
            .onChange(of: selectedId) { _, newValue in
                if let newValue {
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for week: WeekSlot) -> some View {
        let isSelected = week.id == selectedId
        Button {
            onSelect(week)
        } label: {
            let label = Text(compactLabel(week))
                .font(.chip)
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
            // The selected chip is the strip's one piece of floating
            // chrome — ink-tinted glass on iOS 26, the solid capsule on
            // the 18.0 floor. Unselected chips stay bare text.
            if isSelected {
                label.glassCapsuleInteractive(tint: Color.textPrimary,
                                              fallback: Color.textPrimary)
            } else {
                label
            }
        }
        .buttonStyle(.plain)
        // Spoken label uses the full "Week 5", not the compact "Wk 5".
        .accessibilityLabel(week.shortLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(week.id)
    }

    private func compactLabel(_ week: WeekSlot) -> String {
        week.shortLabel.replacingOccurrences(of: "Week ", with: "Wk ")
    }
}
