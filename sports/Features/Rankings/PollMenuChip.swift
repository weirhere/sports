import SwiftUI

/// Which poll the page is showing: `SeasonMenuChip`'s sibling, so the two
/// selectors that ride a content pane read as one control.
struct PollMenuChip: View {
    let polls: [Poll]
    /// The selected poll's type ("ap"), or nil before one is chosen.
    let current: String?
    let onSelect: (String) -> Void

    private var currentType: String { current ?? polls.first?.type ?? "ap" }

    private var currentLabel: String {
        polls.first { $0.type == currentType }.map(PollScreen.label(for:)) ?? "Poll"
    }

    var body: some View {
        Menu {
            Picker("Poll", selection: Binding(get: { currentType }, set: onSelect)) {
                ForEach(polls, id: \.id) { poll in
                    Text(PollScreen.label(for: poll)).tag(poll.type)
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
        .disabled(polls.count < 2)
        .accessibilityLabel("Poll, \(currentLabel)")
    }
}
