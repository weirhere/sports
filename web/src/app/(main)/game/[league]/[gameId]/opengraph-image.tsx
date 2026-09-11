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
import { BrandCard, CardShell } from "@/lib/og/card";
import { interFonts } from "@/lib/og/fonts";
import { logoData } from "@/lib/og/logo";
// `DISC` is the recessed ground doing a second job: the quiet disc a
// logo that wouldn't load degrades to.
import { INK, LIVE, MUTED, RECESSED as DISC } from "@/lib/og/palette";
import { gameSummary } from "@/lib/espn/provider";
import { ogCardModel, type OgCardModel, type OgCardSide } from "./og-card";
import { displayName, parseLeague } from "@/lib/leagues";

export const alt = "StatSide game card";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

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
    // The row is top-aligned inside itself (the app's `.top` HStack); the
    // shell centres it in the canvas, because an OG image is a fixed
    // 1200×630 where the app's card shrinks to its content, and a pre-game
    // card — no scores under the names — would otherwise hang from the
    // ceiling.
    <CardShell>
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
    </CardShell>
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

  if (!league) return new ImageResponse(<BrandCard tagline={tagline} />, options);

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
    return new ImageResponse(<BrandCard tagline={tagline} />, options);
  }
}
