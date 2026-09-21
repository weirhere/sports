import SwiftUI

/// A tab a `HeroTabBar` can render: the value identifies the tab, the raw
/// value orders it (slide direction comes from ordinal comparison), and the
/// title labels it.
protocol HeroTabItem: Hashable {
    var title: String { get }
}

/// The entity pages' hero tab row — the Figma header component's tab specs
/// (Andy, 2026-08-25): 40pt gap, 14pt vertical padding per tab, bold 14
/// labels at −2% tracking. Ink weight alone separates active from inactive
/// (the 3pt underline came out 2026-08-31 — redundant with the ink, and it
/// stays out; contrast was the thing that was actually wrong). One
/// component for TeamPage, ConferencePage, PollScreen and game detail.
struct HeroTabBar<T: HeroTabItem>: View {
    let tabs: [T]
    let selection: T
    let onSelect: (T) -> Void

    /// The unselected tab's ink.
    ///
    /// `textSecondary`, not the `textPrimary.opacity(0.5)` this carried
    /// until 2026-09-21. A half-strength primary composites to white 0.55
    /// on a light card, which is **3.35:1** at bold 14 — under WCAG AA's
    /// 4.5:1 for anything below 18.66pt bold, on a control whose whole job
    /// is to say where else you can go. Dark mode was fine (5.17:1), which
    /// is how it survived: the failure is light-mode only and arithmetic
    /// rather than obvious.
    ///
    /// The app already owns an audited second-rank ink, and its own
    /// reasoning is this reasoning — 0.42 rather than 0.44 precisely so it
    /// clears 4.5:1 on the darkest surface secondary text ever sits on. So
    /// this stops hand-rolling an opacity over an unknown backdrop and
    /// uses the token: 5.32:1 on a light card, 6.37:1 on a dark one, and
    /// 4.55:1 in the worst case anywhere on the ramp. `ContrastTests`
    /// holds every one of those numbers to the surface it was measured on.
    private var inactiveInk: Color { .textSecondary }

    /// The row scrolls itself, and carries its own `Spacing.lg` gutter.
    ///
    /// A five-tab team page — Overview, Games, Standings, Roster,
    /// Trophies — measures wider than an iPhone's content width at bold 14
    /// with 40pt gaps, so as a bare `HStack` it **wrapped**: "Overvie/w",
    /// "Standi/ngs" (Andy, 2026-09-21, screenshot). Wrapping was the worse
    /// half of the prediction in BACKLOG E5, which expected compression —
    /// a truncated label keeps its row height where a wrapped one doesn't,
    /// and this row is a pinned section header (2026-09-05), so the strip
    /// content slides under was changing height.
    ///
    /// The web strip took the same fix a day earlier (`docs/decisions.md`
    /// 2026-09-20) and its two rules carry over. The gutter lives on the
    /// content rather than the scroller so tabs scroll out at the
    /// **surface** edge instead of being sliced off 16pt short of it —
    /// callers hand this an unpadded surface and keep painting their own
    /// background full-bleed. And `lineLimit(1)` + `fixedSize` make the
    /// labels refuse to squeeze: the row overflows into its scroller
    /// rather than compressing, which is the failure that stays legible.
    ///
    /// `scrollBounceBehavior(.basedOnSize)` so a row that fits doesn't
    /// rubber-band. A scroller says there is more here, and on the three-tab
    /// conference, poll and game pages there isn't — the standings table's
    /// rule (2026-09-13), applied to the control instead of the table.
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 40) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            onSelect(tab)
                        } label: {
                            Text(tab.title)
                                .font(.tab)
                                .tracking(-0.28)
                                .lineLimit(1)
                                .fixedSize()
                                .foregroundStyle(selection == tab ? Color.textPrimary : inactiveInk)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(tab)
                        // "Games" is also the first root tab, so a bare title match
                        // is ambiguous the moment an entity page is pushed — the
                        // root tab bar never leaves the tree.
                        .accessibilityIdentifier("hero-tab-\(tab.title.lowercased())")
                        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .accessibilityIdentifier("hero-tab-row")
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // Jump on first paint, animate afterwards — the DayStrip rule,
            // so a tab restored off-screen is simply already in view rather
            // than sliding in front of someone who didn't ask for motion.
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}
