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

    private func chip(for week: WeekSlot) -> some View {
        let isSelected = week.id == selectedId
        return Button {
            onSelect(week)
        } label: {
            Text(compactLabel(week))
                .font(.chip)
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.textPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .id(week.id)
    }

    private func compactLabel(_ week: WeekSlot) -> String {
        week.shortLabel.replacingOccurrences(of: "Week ", with: "Wk ")
    }
}
