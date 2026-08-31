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
struct HeroTabBar<T: HeroTabItem>: View {
    let tabs: [T]
    let selection: T
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 40) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.title)
                        .font(.tab)
                        .tracking(-0.28)
                        .foregroundStyle(selection == tab ? Color.textPrimary : Color.textPrimary.opacity(0.5))
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
    }
}
