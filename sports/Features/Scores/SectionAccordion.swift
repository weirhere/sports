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
                ForEach(section.games) { game in
                    GameRow(game: game)
                    if game.id != section.games.last?.id {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
            Divider().overlay(Color.divider)
        }
    }
}
