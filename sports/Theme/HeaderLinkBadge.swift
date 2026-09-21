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
///
/// **The fill is the *other* surface colour, which is why it is a
/// parameter** (2026-09-20). The default suits the header it was built for:
/// `TeamPage` and `ConferencePage` put their heroes on `bgCard`, so a
/// `bgRecessed` capsule reads as a shape cut into it. `PlayerPage`'s hero
/// sits straight on `bgRecessed`, where that default is the ground itself
/// and the badge disappears — in **both** appearances, since the two are the
/// same value in light (0.93) and `bgElevated` collides there too. A badge
/// on recessed ground passes `.bgCard` and gets the same one step of
/// separation, in the other direction.
struct HeaderLinkBadge: View {
    let title: String
    /// One elevation step away from whatever this badge sits on.
    var fill: Color = .bgRecessed
    /// A mark inside the capsule, where the badge names a team (Andy,
    /// 2026-09-21). It rode outside on the player hero, which read as a
    /// loose logo next to a pill rather than one badge naming one club.
    var logoURL: URL? = nil

    @ScaledMetric(relativeTo: .caption) private var logoSize: CGFloat = 14

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let logoURL {
                LogoImage(url: logoURL)
                    .frame(width: logoSize, height: logoSize)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.chipEmphasis)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(Capsule().fill(fill))
        .contentShape(Capsule())
    }
}

#Preview("On a card header") {
    HStack(spacing: Spacing.xs) {
        HeaderLinkBadge(title: "Northwest (West)")
        HeaderLinkBadge(title: "NBA")
    }
    .padding()
    .background(Color.bgCard)
}

#Preview("On recessed ground — PlayerPage's hero") {
    HStack(spacing: Spacing.xs) {
        HeaderLinkBadge(title: "Tampa Bay", fill: .bgCard)
        // What the default would look like here: nothing.
        HeaderLinkBadge(title: "Invisible")
    }
    .padding()
    .background(Color.bgRecessed)
}
