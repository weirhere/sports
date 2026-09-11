// The chassis every StatSide link preview is built on.
//
// Three cards share it — a game's matchup, a team's and a conference's
// identity — and sharing it is the point: a link to any of them should
// arrive in a thread looking like the same product. Content in the middle,
// a hairline, the wordmark beneath.
//
// Always light. The image is rendered once on our server and then shown to
// everyone who sees the link, so the reader's appearance setting is not
// ours to guess, and a white card reads on any thread background.
//
// Satori note: every div sets `display: flex`, text leaves included.
// Satori throws on a div with more than one child node and no explicit
// display, and a wrapped or segmented string counts as several nodes — so
// a bare text div renders fine until the day a longer name arrives, then
// takes the whole image down.

import type { ReactNode } from "react";
import { DIVIDER, INK, MUTED, PAPER, RECESSED } from "./palette";

/** Facebook's, Slack's and X's shared 1.91:1 — and the app's own card. */
export const OG_SIZE = { width: 1200, height: 630 };

/**
 * The card's outer frame: the content it is given, then the sign-off.
 *
 * The sign-off is the only branding on a card whose body never names the
 * app — the invitation framing the iOS shares adopted (2026-08-09).
 */
export function CardShell({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        width: "100%",
        height: "100%",
        backgroundColor: PAPER,
        fontFamily: "Inter",
      }}
    >
      <div
        style={{
          display: "flex",
          flex: 1,
          flexDirection: "column",
          justifyContent: "center",
          padding: "32px 48px",
        }}
      >
        {children}
      </div>
      <div style={{ display: "flex", height: 1, backgroundColor: DIVIDER }} />
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "24px 0 28px",
          fontSize: 30,
          fontWeight: 700,
          letterSpacing: -0.4,
          color: INK,
        }}
      >
        StatSide
      </div>
    </div>
  );
}

/**
 * The card an entity we couldn't load still deserves: the brand, and no
 * lies. Its own layout rather than the shell's, because the wordmark *is*
 * the content here — putting it in the shell would print it twice.
 */
export function BrandCard({ tagline }: { tagline: string }) {
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
        width: "100%",
        height: "100%",
        backgroundColor: PAPER,
        fontFamily: "Inter",
      }}
    >
      <div style={{ display: "flex", fontSize: 64, fontWeight: 700, letterSpacing: -1, color: INK }}>
        StatSide
      </div>
      <div style={{ display: "flex", fontSize: 32, color: MUTED }}>{tagline}</div>
    </div>
  );
}

/**
 * A mark at card scale, or the quiet disc one that wouldn't load degrades
 * to. A plain `<img>`, not `next/image`: this tree is drawn by Satori,
 * which knows nothing of Next's image pipeline.
 */
export function CardLogo({
  src,
  size = 160,
}: {
  src: string | null;
  size?: number;
}) {
  if (!src) {
    return (
      <div
        style={{
          display: "flex",
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: RECESSED,
        }}
      />
    );
  }
  return (
    // Satori draws this tree itself and knows nothing of Next's image
    // pipeline. The rule is off by default *inside* an `opengraph-image`
    // file; this is the same markup, living one directory over.
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      width={size}
      height={size}
      alt=""
      style={{ objectFit: "contain" }}
    />
  );
}

/**
 * A team's or a conference's card: the entity pages' hero at poster size —
 * mark, name, and the one line of context the page's own hero carries.
 *
 * The league rides *above* the name as a kicker rather than below it. The
 * app never has to say which league you are looking at (you got there
 * through one), but a link preview arrives with no such context, and
 * "Jackets" is a different team in three of the four leagues this app
 * covers.
 */
export function EntityCard({
  kicker,
  logo,
  title,
  subtitle,
}: {
  kicker?: string;
  logo: string | null;
  title: string;
  subtitle?: string;
}) {
  return (
    <CardShell>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 22,
        }}
      >
        <CardLogo src={logo} />
        {kicker ? (
          <div
            style={{
              display: "flex",
              fontSize: 24,
              fontWeight: 600,
              letterSpacing: 2,
              color: MUTED,
            }}
          >
            {kicker}
          </div>
        ) : null}
        {/* `.fixedSize()`'s equivalent, in effect: the name is the card's
            headline and shrinking it to fit would hide the fact that it
            didn't. A long name wraps, and the column absorbs it. */}
        <div
          style={{
            display: "flex",
            marginTop: kicker ? -8 : 0,
            fontSize: 78,
            fontWeight: 700,
            letterSpacing: -2,
            color: INK,
            textAlign: "center",
            lineHeight: 1.1,
          }}
        >
          {title}
        </div>
        {subtitle ? (
          <div style={{ display: "flex", fontSize: 36, color: MUTED }}>
            {subtitle}
          </div>
        ) : null}
      </div>
    </CardShell>
  );
}
