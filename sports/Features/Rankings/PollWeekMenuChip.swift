import SwiftUI

/// Which week of the season the Top 25 table is showing (Andy, 2026-09-27):
/// flip back through a season to see where a team stood in Week 6.
/// `PollMenuChip`'s sibling, and the same capsule.
///
/// Newest first, like the season menu beside it: the week you most often
/// want is the latest, and it should sit where the thumb lands.
struct PollWeekMenuChip: View {
    /// Oldest first, as the client returns them.
    let weeks: [PollWeek]
    let current: PollWeek
    let onSelect: (PollWeek) -> Void

    var body: some View {
        Menu {
            Picker("Week", selection: Binding(get: { current }, set: onSelect)) {
                ForEach(weeks.reversed(), id: \.self) { week in
                    Text(week.label).tag(week)
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(current.label)
                    .font(.chip)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .glassCapsuleInteractive(fallback: Color.bgElevated)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(weeks.count < 2)
        .accessibilityLabel("Week, \(current.label)")
        .accessibilityIdentifier("poll-week-chip")
    }
}

#Preview {
    PollWeekMenuChip(weeks: [PollWeek(seasonType: 1, number: 1),
                             PollWeek(seasonType: 2, number: 2),
                             PollWeek(seasonType: 3, number: 1)],
                     current: PollWeek(seasonType: 3, number: 1),
                     onSelect: { _ in })
        .padding()
        .background(Color.bgRecessed)
}
