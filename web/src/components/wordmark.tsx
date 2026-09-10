// The app's name, set as a mark rather than as a label — the web twin of iOS
// `Wordmark`.
//
// The glyph that used to lead it retired on 2026-09-09: the tab bar's own
// Games icon is a football too, so the header was saying "sports" twice a
// thumb apart, and a stock icon beside a stock system-font string reads as a
// placeholder logo — which is what it was. With the glyph gone the name has
// room to carry the identity by itself.
//
// Three moves make system type read as drawn type, all inside the monochrome
// budget — a wordmark that wants colour wants weight instead:
//
//   - **A weight split.** "Stat" in black against "Side" in medium is the
//     compound-word lockup, and it says which half of the name is the noun.
//     Medium and not regular: at 900-against-400 the two halves read as two
//     words that happened to touch, and the mark has to read as one.
//   - **A width variant.** The system stack's condensed cut is the single
//     thing that stops the string looking like the system font, and it buys
//     back the width the larger size spends — measured at 24px it is ~13%
//     narrower than the normal cut. A browser without the width axis simply
//     renders normal width; the weight split and the tracking still carry.
//   - **Tight tracking.** −3%, a touch past the hero tabs' −2%, so the two
//     weights close up into one shape.

export function Wordmark({
  /**
   * Point size. 24 in the nav bar — the app's own hero-title scale, for the
   * same reason the entity pages use it: nothing above it names the screen.
   */
  size = 24,
  className,
}: {
  size?: number;
  className?: string;
}) {
  return (
    <span
      aria-label="StatSide"
      role="img"
      className={className}
      style={{
        fontSize: size,
        fontStretch: "condensed",
        letterSpacing: "-0.03em",
        lineHeight: 1,
        whiteSpace: "nowrap",
      }}
    >
      <span aria-hidden="true" style={{ fontWeight: 900 }}>
        Stat
      </span>
      <span aria-hidden="true" style={{ fontWeight: 500 }}>
        Side
      </span>
    </span>
  );
}
