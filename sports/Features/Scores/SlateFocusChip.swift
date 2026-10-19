import SwiftUI

/// The Scores header's one scope control (Andy, 2026-10-19): a menu chip
/// reading "All games", "Live" or "Tight", in place of the Live and Tight
/// pills. The season chip's shape — label, `chevron.up.chevron.down` — in
/// the header capsule's own pill.
///
/// The fills are the pills' (2026-09-12, 2026-09-24): Live wears the live
/// tint under its edge with the green dot before the word, because the
/// chip *is* the live affordance; Tight wears an ink wash, since one
/// header doesn't spend the green twice; All games paints nothing. `focus`
/// is the filter as it applies to the day on screen, not the remembered
/// one — off today it is suspended, and the chip says "All games".
struct SlateFocusChip: View {
    let focus: SlateFocus
    let onSelect: (SlateFocus) -> Void

    var body: some View {
        Menu {
            // Buttons, not a Picker: a picker row is one line, and each
            // choice here carries its description under its name. The check
            // the picker would have drawn is the row's icon.
            ForEach(SlateFocus.allCases) { choice in
                Button {
                    onSelect(choice)
                } label: {
                    Label {
                        Text(choice.title)
                        Text(choice.detail)
                    } icon: {
                        if choice == focus { Image(systemName: "checkmark") }
                    }
                }
                .accessibilityAddTraits(choice == focus ? .isSelected : [])
            }
        } label: {
            HStack(spacing: 6) {
                if focus == .live {
                    Circle()
                        .fill(Color.liveAccent)
                        .frame(width: 8, height: 8)
                }
                Text(focus.title)
                    .font(.chipEmphasis)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().strokeBorder(edge, lineWidth: 1))
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: focus)
        .accessibilityLabel("Games shown")
        .accessibilityValue(focus.title)
        .accessibilityIdentifier("scores-focus-chip")
    }

    private var fill: Color {
        switch focus {
        case .all: .clear
        case .live: .liveTint
        case .tight: Color.textPrimary.opacity(0.1)
        }
    }

    private var edge: Color {
        switch focus {
        case .all: .clear
        case .live: .liveEdge
        case .tight: Color.textPrimary.opacity(0.35)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ForEach(SlateFocus.allCases) { focus in
            SlateFocusChip(focus: focus, onSelect: { _ in })
        }
    }
    .padding()
    .background(Color.bgPrimary)
}
