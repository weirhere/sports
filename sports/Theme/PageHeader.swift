import SwiftUI

/// A root tab's own chrome row: the page's name at the leading edge, its
/// controls at the trailing one (Andy, 2026-09-21).
///
/// Games drew this itself and the other two used `.navigationTitle` with
/// `.inline`, which centres — so three root tabs had two different
/// mastheads, and the eye caught it moving between them. This is the Games
/// row's geometry extracted rather than re-specified: `Spacing.lg` gutter,
/// `Spacing.sm` above, 21pt heavy type, trailing controls in the same slot
/// the Live and calendar chips occupy.
///
/// **The 52pt floor is the whole reason this is a component.** On Games the
/// row's height comes from the grouped capsule — a 44pt minimum tap target
/// plus the capsule's own 4pt of padding on each side. A tab whose trailing
/// control is a bare button would otherwise make a shorter row and centre
/// that button a few points higher, which is exactly the misalignment
/// between tabs this exists to remove. Stating the floor here means every
/// tab's controls sit on one line across the whole app, whatever they are.
struct PageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    /// The Games capsule's height: `calendarButton`'s 44pt minimum plus the
    /// capsule's 4pt padding, top and bottom.
    private let rowHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: rowHeight)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

extension PageHeader where Trailing == EmptyView {
    /// A tab with no controls of its own — the title still sits where every
    /// other tab's does, and the row keeps its height so the page below
    /// starts at the same place.
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 0) {
        PageHeader("Leagues")
        PageHeader(title: "Teams") {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
        }
    }
    .background(Color.bgPrimary)
}
