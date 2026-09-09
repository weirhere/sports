import SwiftUI

/// The app's name, set as a mark rather than as a label.
///
/// The field glyph that used to lead it retired on 2026-09-09 (Andy): the
/// tab bar's own Games icon is the same `sportscourt.fill`, so the header
/// was saying "sports" twice a thumb apart, and a stock SF Symbol beside a
/// stock SF Pro string reads as a placeholder logo. With the glyph gone the
/// name has room to carry the identity by itself.
///
/// Three moves make system type read as drawn type, all of them inside the
/// monochrome budget — a wordmark that wants colour wants weight instead:
///
/// - **A weight split.** "Stat" in black against "Side" in medium is the
///   compound-word lockup, and it says which half of the name is the noun.
///   Medium and not regular: at 900-against-400 the two halves read as two
///   words that happened to touch, and the mark has to read as one.
/// - **A width variant.** SF Pro's condensed cut (iOS 16+, so it clears the
///   18.0 floor) is the single thing that stops the string looking like the
///   system font, and it buys back the width the larger size spends.
/// - **Tight tracking.** −3%, a touch past the hero tabs' −2%, so the two
///   weights close up into one shape.
struct Wordmark: View {
    /// Point size. 24 on the Scores header — the app's own
    /// `heroTitle` scale, for the same reason entity pages use it: nothing
    /// above it is naming the screen.
    var size: CGFloat = 24

    var body: some View {
        (Text("Stat").font(face(.black)) + Text("Side").font(face(.medium)))
            .tracking(size * -0.03)
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
            .accessibilityLabel("StatSide")
    }

    /// UIKit stays contained the way `Font`'s own tokens contain it: the
    /// width axis has no SwiftUI spelling before iOS 26.
    private func face(_ weight: UIFont.Weight) -> Font {
        Font(UIFont.systemFont(ofSize: size, weight: weight, width: .condensed))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Wordmark()
        Wordmark(size: 18)   // the share card's sign-off
    }
    .padding()
    .background(Color.bgPrimary)
}
