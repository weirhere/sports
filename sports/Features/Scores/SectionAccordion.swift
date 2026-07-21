import SwiftUI

/// One collapsible section of the scores list: quiet uppercase header,
/// hairline-divided game rows when expanded.
struct SectionAccordion: View {
    let section: GameSection
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.sm) {
                    Text(section.title.uppercased())
                        .font(.sectionHeader)
                        .foregroundStyle(.textPrimary)
                    Text("\(section.games.count)")
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(section.games.enumerated()), id: \.element.id) { index, game in
                    if let label = dayDivider(at: index) {
                        Text(label)
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, index == 0 ? 0 : Spacing.sm)
                            .padding(.bottom, Spacing.xs)
                    }
                    NavigationLink(value: game) {
                        GameRow(game: game)
                    }
                    .buttonStyle(.plain)
                    if game.id != section.games.last?.id {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
        }
    }

    // MARK: - Day dividers
    // Whisper-quiet "SAT, AUG 29" labels, only when the section spans more
    // than one day. Dates included, not just weekdays — ESPN weeks can span
    // two weekends (2026's Week 1 does).

    private var spansMultipleDays: Bool {
        Set(section.games.compactMap { $0.date.map(Calendar.current.startOfDay(for:)) }).count > 1
    }

    private func dayDivider(at index: Int) -> String? {
        guard spansMultipleDays, let date = section.games[index].date else { return nil }
        if index > 0, let previous = section.games[index - 1].date,
           Calendar.current.isDate(previous, inSameDayAs: date) {
            return nil
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
    }
}
