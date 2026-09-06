import SwiftUI

/// Which poll the page is showing: `SeasonMenuChip`'s sibling, so the two
/// selectors that ride a content pane read as one control.
struct PollMenuChip: View {
    let polls: [Poll]
    /// The selected poll's type ("ap"), or nil before one is chosen.
    let current: String?
    let onSelect: (String) -> Void

    /// The menu's rows as (type, label) pairs, so every `tag` is statically
    /// a `String` — the selection binding's own type.
    ///
    /// This is the whole reason the pairs exist. `Poll.type` is `String?`,
    /// and tagging rows with it while binding the selection to a `String`
    /// gave SwiftUI a tag type it could never match: no row read as
    /// selected, and picking one couldn't write back, so the chip looked
    /// alive and did nothing (Andy, 2026-09-06 — "the AP/coaches filter
    /// isn't working"). A poll ESPN sent no type for isn't offered at all,
    /// because the type *is* the selection value.
    private var options: [(type: String, label: String)] {
        polls.compactMap { poll in
            poll.type.map { (type: $0, label: PollScreen.label(for: poll)) }
        }
    }

    private var currentType: String { current ?? options.first?.type ?? "ap" }

    private var currentLabel: String {
        options.first { $0.type == currentType }?.label ?? "Poll"
    }

    var body: some View {
        Menu {
            Picker("Poll", selection: Binding(get: { currentType }, set: onSelect)) {
                ForEach(options, id: \.type) { option in
                    Text(option.label).tag(option.type)
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(currentLabel)
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
        .disabled(options.count < 2)
        .accessibilityLabel("Poll, \(currentLabel)")
    }
}
