import SwiftUI

/// A tab a `HeroTabBar` can render: the value identifies the tab, the raw
/// value orders it (slide direction comes from ordinal comparison), and the
/// title labels it.
protocol HeroTabItem: Hashable {
    var title: String { get }
}

/// The entity pages' hero tab row — the Figma header component's tab specs
/// (Andy, 2026-08-25): 40pt gap, 14pt vertical padding per tab, bold 14
/// labels at −2% tracking. Opacity alone separates active from inactive
/// (the 3pt underline came out 2026-08-31 — redundant with the 50% ink).
/// One component for TeamPage and ConferencePage.
///
/// The row scrolls horizontally rather than squeezing (Andy, 2026-09-18).
/// Five tabs plus a long word — a team page with Standings, Roster and
/// Trophies — used to wrap "Overview" onto two lines and shred the row's
/// baseline. The day strip already runs off both edges on the Scores
/// screen, so a strip that keeps going is a shape the app has. The gutter
/// lives inside the scroll content for the same reason it does there: a
/// tab scrolling past the edge should meet the screen, not a margin.
struct HeroTabBar<T: HeroTabItem>: View {
    let tabs: [T]
    let selection: T
    let onSelect: (T) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 40) {
                    ForEach(tabs, id: \.self) { tab in
                        button(for: tab)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            // Nothing to scroll when the tabs fit, and a row that rubber-bands
            // on a two-tab page would read as a bug.
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func button(for tab: T) -> some View {
        Button {
            onSelect(tab)
        } label: {
            // fixedSize: the row can outrun the screen now, so a label has
            // no reason to wrap or truncate — that was the whole complaint.
            Text(tab.title)
                .font(.tab)
                .tracking(-0.28)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(selection == tab ? Color.textPrimary : Color.textPrimary.opacity(0.5))
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // "Games" is also the first root tab, so a bare title match
        // is ambiguous the moment an entity page is pushed — the
        // root tab bar never leaves the tree.
        .accessibilityIdentifier("hero-tab-\(tab.title.lowercased())")
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
        .id(tab)
    }
}
