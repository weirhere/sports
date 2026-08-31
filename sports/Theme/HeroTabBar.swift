import SwiftUI

/// A tab a `HeroTabBar` can render: the value identifies the tab, the raw
/// value orders it (slide direction comes from ordinal comparison), and the
/// title labels it.
protocol HeroTabItem: Hashable {
    var title: String { get }
}

/// The entity pages' hero tab row — the Figma header component's tab specs,
/// followed exactly (Andy, 2026-08-25): 40pt gap, 14pt vertical padding per
/// tab, bold 14 labels at −2% tracking, a 3pt bottom bar spanning the tab,
/// inactive ink at 50%. One component for TeamPage and ConferencePage,
/// extracted when TeamPage grew a third tab (2026-08-31).
struct HeroTabBar<T: HeroTabItem>: View {
    let tabs: [T]
    let selection: T
    let ink: Color
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
                        .foregroundStyle(selection == tab ? ink : ink.opacity(0.5))
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selection == tab ? ink : Color.clear)
                                .frame(height: 3)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
    }
}
