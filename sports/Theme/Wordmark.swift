import SwiftUI

/// The app's name, in plain system type.
///
/// **Plain, and no glyph.** The 2026-09-09 drawn-mark treatment — SF Pro's
/// condensed width axis, "Stat" in black against "Side" in medium, −3%
/// tracking, and the 17 → 24 size it bought — is reverted (Andy, 2026-09-10:
/// *"we changed this back on the web version. we need to update here on iOS as
/// well"*, following the web's own revert the same day). The width axis, the
/// weight split and the tight tracking were what made system type read as
/// drawn type; in place they read as system type trying to look drawn, which
/// is a judgment only the eye makes. The size comes down with them — 24 was
/// affordable *because* the condensed cut bought the width back — but not all
/// the way to the original 17: Andy's call at 21, which keeps the masthead
/// carrying the screen without the plain cut's full width at 24.
///
/// The one thing that doesn't come back is the field glyph. Its own argument
/// still holds: `sportscourt.fill` is also the Games tab's icon, so the header
/// said "sports" twice a thumb apart, and a stock SF Symbol beside a stock SF
/// Pro string reads as a placeholder logo.
///
/// The real answer to a placeholder wordmark is a drawn one, which needs a
/// licence and a designer. This is honest about being system type until there
/// is one.
struct Wordmark: View {
    /// Point size. 21 on the Scores header; 15 on the share card's sign-off,
    /// the value it carried before the stylization — the card is a share site,
    /// not the app's own chrome, so it doesn't follow the masthead up.
    var size: CGFloat = 21

    var body: some View {
        Text("StatSide")
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Wordmark()
        Wordmark(size: 15)   // the share card's sign-off
    }
    .padding()
    .background(Color.bgPrimary)
}
