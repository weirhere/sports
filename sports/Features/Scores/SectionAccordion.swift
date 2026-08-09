import SwiftUI

/// One collapsible section of the scores list: gray-filled header,
/// hairline-divided game rows when expanded.
struct SectionAccordion: View {
    let section: GameSection
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(FollowingStore.self) private var following

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.sm) {
                    if section.isConference {
                        ConferenceLogo(url: section.logoURL)
                    } else if let symbol = headerSymbol {
                        // Same footprint as ConferenceLogo so every section
                        // title starts at the same x.
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 18, height: 18)
                    }
                    Text(section.title)
                        .font(.sectionHeader)
                        .foregroundStyle(.textPrimary)
                    Text("\(section.games.count)")
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.bgHeader)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(section.title), \(section.games.count) \(section.games.count == 1 ? "game" : "games")")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isHeader)

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
                    .contextMenu {
                        followMenuButton(for: game.away.team)
                        followMenuButton(for: game.home.team)
                        ShareLink(item: game.shareText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    // The row collapses to one VO element, which swallows
                    // the menu — custom actions restore parity.
                    .accessibilityAction(named: followActionTitle(for: game.away.team)) {
                        following.toggle(game.away.team.id)
                    }
                    .accessibilityAction(named: followActionTitle(for: game.home.team)) {
                        following.toggle(game.home.team.id)
                    }
                    if game.id != section.games.last?.id {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
        }
    }

    private func followMenuButton(for team: Team) -> some View {
        Button {
            following.toggle(team.id)
        } label: {
            Label(followActionTitle(for: team),
                  systemImage: following.isFollowing(team.id) ? "star.slash" : "star")
        }
    }

    private func followActionTitle(for team: Team) -> String {
        following.isFollowing(team.id) ? "Unfollow \(team.location)" : "Follow \(team.location)"
    }

    /// Header glyph for the non-conference sections. star.fill echoes the
    /// follow toggle on team pages; trophy.fill marks the poll; day
    /// sections get a calendar so their titles x-align with Following's.
    private var headerSymbol: String? {
        switch section.id {
        case GameSection.followingId: "star.fill"
        case GameSection.top25Id: "trophy.fill"
        case let id where id.hasPrefix(GameSection.dayPrefix): "calendar"
        default: nil
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
