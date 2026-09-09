// The graphic a game link wears when it's pasted into Slack, posted on X,
// or sent anywhere that unfurls a URL.
//
// Why this exists at all: iMessage takes a preview image straight from the
// *sender* (the iOS app hands it one via `LPLinkMetadata`), but every other
// unfurler builds the card on its own server by fetching the URL and
// reading its `og:` tags. Nothing the app does can reach them — only a page
// we serve can. This is that page's image.
//
// It renders the iOS share card's layout (`GameShareCardView.swift`): logos
// flanking a status column, the kickoff time headlining a game that hasn't
// started, a divider and the wordmark beneath. Always light, like the app's
// card — the recipient's dark mode is not ours to guess, and a white card
// reads on any thread background.
//
// Two rules hold this file together, both inherited from the app's card:
//   1. It must never fail. An unfurler that gets a 500 shows no image at
//      all, which is worse than a plain one — so a missing logo degrades to
//      a quiet disc, a missing font degrades to the default, and an
//      unknown game id degrades to a wordmark card.
//   2. It must never invent. No 0–0 before kickoff, no score we don't have.
//
// Satori note: every div here sets `display: flex`, text leaves included.
// Satori throws on a div with more than one child node and no explicit
// display, and a wrapped or segmented string counts as several nodes — so
// a bare text div renders fine until the day a longer name arrives, then
// takes the whole image down. A fragment is worse: its children lay out in
// a row, which is why the kickoff stack is a real div.

import { ImageResponse } from "next/og";
import { gameSummary } from "@/lib/espn/provider";
import { ogCardModel, type OgCardModel, type OgCardSide } from "./og-card";
import { displayName, parseLeague } from "@/lib/leagues";

export const alt = "StatSide game card";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

// The app's ink, verbatim from globals.css — the card is always light, so
// these are the light values with no dark twin.
const INK = "#1a1a1a";
const MUTED = "#6b6b6b";
const DIVIDER = "#e0e0e0";
const PAPER = "#ffffff";
/** The placeholder disc a logo that wouldn't load degrades to. */
const DISC = "#ededed";
/** The app's one green: the live accent shares rank-up (2026-08-29). */
const LIVE = "#008538";

/**
 * Inter stands in for SF Pro: Satori has no system fonts, and its built-in
 * fallback ships one weight — which would flatten a card whose whole
 * hierarchy is weight and size. Bundled rather than fetched so rendering
 * costs no network hop and can't fail halfway.
 */
async function interFonts() {
  const weights = [
    { file: "inter-latin-400-normal.woff", weight: 400 as const },
    { file: "inter-latin-600-normal.woff", weight: 600 as const },
    { file: "inter-latin-700-normal.woff", weight: 700 as const },
  ];
  try {
    return await Promise.all(
      weights.map(async ({ file, weight }) => ({
        name: "Inter",
        weight,
        style: "normal" as const,
        data: await fetch(
          new URL(`../../../../../lib/og/fonts/${file}`, import.meta.url)
        ).then((res) => res.arrayBuffer()),
      }))
    );
  } catch {
    // Rule 1: a card in the fallback font beats no card.
    return undefined;
  }
}

/**
 * Satori fetches remote images itself and *throws* when one won't load, so
 * a cold ESPN CDN would take the whole card down. Fetching them here turns
 * that into a placeholder disc — the app's own rule for the same gap.
 */
async function logoData(url: string | undefined): Promise<string | null> {
  if (!url) return null;
  try {
    const res = await fetch(url, {
      signal: AbortSignal.timeout(2000),
      next: { revalidate: 86400 },
    });
    if (!res.ok) return null;
    const buffer = Buffer.from(await res.arrayBuffer());
    const type = res.headers.get("content-type") ?? "image/png";
    return `data:${type};base64,${buffer.toString("base64")}`;
  } catch {
    return null;
  }
}

function Logo({ src }: { src: string | null }) {
  if (!src) {
    return (
      <div
        style={{
          width: 160,
          height: 160,
          borderRadius: 80,
          backgroundColor: DISC,
        }}
      />
    );
  }
  // A plain <img>, not next/image: this tree is rendered by Satori, which
  // knows nothing of Next's image pipeline.
  return <img src={src} width={160} height={160} alt="" style={{ objectFit: "contain" }} />;
}

function Side({ side, logo, showsScores, isLive }: {
  side: OgCardSide;
  logo: string | null;
  showsScores: boolean;
  isLive: boolean;
}) {
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 16,
        flex: 1,
      }}
    >
      <Logo src={logo} />
      <div
        style={{
          display: "flex",
          fontSize: 48,
          fontWeight: side.isWinner === true ? 600 : 400,
          color: INK,
          textAlign: "center",
          lineHeight: 1.2,
        }}
      >
        {side.name}
      </div>
      {side.record ? (
        <div style={{ display: "flex", fontSize: 34, color: MUTED }}>{side.record}</div>
      ) : null}
      {showsScores && side.score !== null ? (
        <div
          style={{
            display: "flex",
            fontSize: 88,
            fontWeight: isLive ? 700 : 600,
            // A side we know lost keeps the muted ink, so the winner reads
            // without color — the app's whole monochrome bargain. "Unknown"
            // (a live game, a final ESPN hasn't called) is not "lost".
            color: side.isWinner === false ? MUTED : INK,
          }}
        >
          {side.score}
        </div>
      ) : null}
    </div>
  );
}

function Card({ model, awayLogo, homeLogo }: {
  model: OgCardModel;
  awayLogo: string | null;
  homeLogo: string | null;
}) {
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
      {/* The row is top-aligned inside itself (the app's `.top` HStack) but
          centered in the canvas: an OG image is a fixed 1200×630 where the
          app's card shrinks to its content, and a pre-game card — no scores
          under the names — would otherwise hang from the ceiling. */}
      <div
        style={{
          display: "flex",
          flex: 1,
          flexDirection: "column",
          justifyContent: "center",
          padding: "32px 48px",
        }}
      >
      <div
        style={{
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "center",
          gap: 24,
        }}
      >
        <Side side={model.away} logo={awayLogo} showsScores={model.showsScores} isLive={model.isLive} />
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 12,
            // Wider than the sides: "12:30 PM ET" is half again as many
            // characters as the score line this slot holds once a game
            // starts, and an equal third can't hold it at this size.
            flex: 1.35,
            paddingTop: model.showsScores ? 40 : 24,
          }}
        >
          {model.isLive ? (
            <div
              style={{
                width: 16,
                height: 16,
                borderRadius: 8,
                backgroundColor: LIVE,
                marginBottom: 4,
              }}
            />
          ) : null}
          {model.kickoff ? (
            // An explicit column, not a fragment: Satori lays a fragment's
            // children out in a row, which put the date beside the time.
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 8,
              }}
            >
              <div style={{ display: "flex", fontSize: 68, fontWeight: 600, color: INK, whiteSpace: "nowrap" }}>
                {model.kickoff.time}
              </div>
              <div style={{ display: "flex", fontSize: 42, color: MUTED }}>{model.kickoff.date}</div>
            </div>
          ) : (
            <div style={{ display: "flex", fontSize: 44, fontWeight: 600, color: INK, textAlign: "center" }}>
              {model.status}
            </div>
          )}
          {model.broadcast ? (
            <div style={{ display: "flex", fontSize: 34, color: MUTED }}>{model.broadcast}</div>
          ) : null}
        </div>
        <Side side={model.home} logo={homeLogo} showsScores={model.showsScores} isLive={model.isLive} />
      </div>
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

/** The card a game we couldn't load still deserves: the brand, and no lies. */
function FallbackCard({ tagline }: { tagline: string }) {
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

export default async function Image({
  params,
}: {
  params: Promise<{ league: string; gameId: string }>;
}) {
  const { league: leagueParam, gameId } = await params;
  const league = parseLeague(leagueParam);
  const fonts = await interFonts();
  const options = { ...size, ...(fonts ? { fonts } : {}) };
  // The fallback card names whatever league the URL claimed — it renders
  // when the summary fetch failed, which says nothing about the league.
  const tagline = league ? `${displayName(league)} scores` : "Live scores";

  if (!league) return new ImageResponse(<FallbackCard tagline={tagline} />, options);

  try {
    // Next memoizes the fetch, so this shares the page's own summary call.
    const { game } = await gameSummary(league, gameId);
    const model = ogCardModel(game);
    const [awayLogo, homeLogo] = await Promise.all([
      logoData(model.away.logoUrl),
      logoData(model.home.logoUrl),
    ]);
    return new ImageResponse(
      <Card model={model} awayLogo={awayLogo} homeLogo={homeLogo} />,
      options
    );
  } catch {
    return new ImageResponse(<FallbackCard tagline={tagline} />, options);
  }
}
