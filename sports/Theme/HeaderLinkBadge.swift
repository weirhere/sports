import SwiftUI

/// One tappable crumb in a page header — the group a team plays in, the
/// league that group belongs to.
///
/// A badge rather than a trailing chevron (Andy, 2026-09-09). A chevron
/// can only say "this line goes somewhere", which is a lie the moment the
/// line holds two names going to two different places: "Northwest (West) ·
/// NBA ›" reads as one link with a stray word in it. Giving each name its
/// own outline says how many destinations there are and where each one
/// starts, without a word of explanation.
///
/// Quiet on purpose: a recessed fill and secondary ink, so a header full
/// of them still reads as a subtitle under the title rather than a row of
/// buttons competing with it.
struct HeaderLinkBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.chipEmphasis)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.bgRecessed))
            .contentShape(Capsule())
    }
}

#Preview {
    HStack(spacing: Spacing.xs) {
        HeaderLinkBadge(title: "Northwest (West)")
        HeaderLinkBadge(title: "NBA")
    }
    .padding()
    .background(Color.bgCard)
}
