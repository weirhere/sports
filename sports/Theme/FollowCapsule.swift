import SwiftUI

/// The follow control on browse rows, drawn: a grey-filled "Follow"
/// capsule while not following, an outlined "Following" one once you are
/// (Andy, 2026-09-27, replacing the stars) — league and conference rows on
/// the tables hub, team rows and cards everywhere else. A word says what
/// a tap does where a star only hinted, and the fill-to-outline swap is
/// weight, not color.
///
/// Only the label — the buttons that drive the team, conference and poll
/// follow sets wrap it, so each keeps its own store call and spoken label.
struct FollowCapsule: View {
    let isFollowing: Bool

    /// The row control's tap target, and so what a league header on the
    /// hub measures (`TablesScreen.headerHeight`).
    static let height: CGFloat = 34

    var body: some View {
        ZStack {
            // Both words laid out, one shown: the capsule is always as wide
            // as "Following", so a tap doesn't resize it under the thumb
            // and every row's control shares one leading edge.
            label("Following").hidden()
            label(isFollowing ? "Following" : "Follow")
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isFollowing ? Color.clear : Color.bgInset)
        )
        .overlay(
            Capsule().strokeBorder(Color.textPrimary.opacity(isFollowing ? 0.35 : 0),
                                   lineWidth: 1)
        )
        .frame(minHeight: Self.height)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: isFollowing)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.metaEmphasis)
            .lineLimit(1)
            .fixedSize()
    }
}
