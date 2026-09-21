import SwiftUI

/// What the search list is narrowed to (Andy, 2026-09-21, from FotMob).
///
/// These replace the section headings the results used to carry. A heading
/// names what you are looking at; a pill lets you ask for it — and with the
/// mixed "All" list broken into one card per result, the headings were
/// doing less work than the row's own league tag already does.
///
/// `players` is here although the ask named only teams, games and
/// conferences: athletes joined search the same day, and a taxonomy that
/// can't narrow to the newest kind of result would be wrong the moment it
/// shipped.
enum SearchScope: String, CaseIterable, Identifiable, Hashable {
    case all, teams, players, games, conferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .teams: "Teams"
        case .players: "Players"
        case .games: "Games"
        case .conferences: "Conferences"
        }
    }
}

/// The scope row: one filled pill per kind of result.
///
/// **It scrolls.** Five pills do not fit a phone at bold type, and the
/// lesson of the hero tab row earlier the same day is that a fixed row of
/// labels does not fail by truncating — it wraps, and a wrapped control row
/// changes height under whatever sits below it. So the labels refuse to
/// squeeze (`lineLimit(1)` + `fixedSize`) and the overflow goes into a
/// scroller that carries its own `Spacing.lg` gutter.
///
/// Filled, unlike the day strip's chips, which are deliberately ink-only.
/// The difference is what the control means: a day is a position on an axis
/// where one is always current, so weight alone reads correctly. A scope is
/// a filter that is either on or off, and the app already paints that state
/// — the Follow pill is a filled capsule when following.
struct SearchScopePills: View {
    let selection: SearchScope
    let onSelect: (SearchScope) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SearchScope.allCases) { scope in
                        pill(for: scope)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityIdentifier("search-scope-pills")
            .onChange(of: selection) { _, scope in
                withAnimation { proxy.scrollTo(scope, anchor: .center) }
            }
        }
    }

    private func pill(for scope: SearchScope) -> some View {
        let isSelected = scope == selection
        return Button {
            onSelect(scope)
        } label: {
            Text(scope.title)
                .font(isSelected ? .chipEmphasis : .chip)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .frame(minHeight: 34)
                .background(
                    Capsule().fill(isSelected ? Color.textPrimary : Color.bgCard)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .id(scope)
        .accessibilityIdentifier("search-scope-\(scope.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading) {
        SearchScopePills(selection: .all) { _ in }
        SearchScopePills(selection: .players) { _ in }
    }
    .background(Color.bgRecessed)
}
