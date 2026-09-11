// The graphic statside.co wears when the site itself is shared.
//
// The per-game card (`game/[league]/[gameId]/opengraph-image.tsx`) has
// covered a *game* link since 2026-09-09. A link to the site had nothing:
// no `og:image` at all, which is why a post of statside.co unfurled as a
// grey placeholder box with a torn-page icon in it. This is that hole.
//
// Because Next's metadata file conventions cascade, this is also the card
// every other route inherits — Leagues, Teams, a team page, a conference
// page — none of which had an image either. A game page still overrides it
// with its own matchup card, which is the one page whose answer is better
// than the brand's.
//
// What it says, in three tiers of one monochrome hierarchy: the name, the
// promise, the leagues. Then the product, drawn.
//
// Always light, like the game card, and for the same reason: the image is
// rendered once on our server and shown to everyone who sees the link, so
// the reader's appearance setting is not ours to guess.
//
// **It renders no live data and fetches nothing.** An unfurler caches what
// it gets — a failure sticks in Slack and on X for as long as the cache
// holds — so the one card that represents the whole product is built out
// of local type and local shapes, with no request that could fail.
//
// Satori note (the same trap the game card documents): every div sets
// `display: flex`, text leaves included. Satori throws on a div with more
// than one child node and no explicit display, and a wrapped string counts
// as several nodes — so a bare text div renders fine until the day a
// longer string arrives, then takes the whole image down.

import { ImageResponse } from "next/og";
import { interFonts } from "@/lib/og/fonts";
import { DIVIDER, INK, LIVE, MUTED, PAPER, RECESSED } from "@/lib/og/palette";

export const alt =
  "StatSide — fast, focused scores for college football, the NFL, the NBA and the NHL";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** A rounded bar: the shape a line of type makes at this scale. */
function Bar({
  w,
  h = 10,
  color = MUTED,
}: {
  w: number;
  h?: number;
  color?: string;
}) {
  return (
    <div
      style={{
        display: "flex",
        width: w,
        height: h,
        borderRadius: h / 2,
        backgroundColor: color,
        flexShrink: 0,
      }}
    />
  );
}

/** A team's mark, at the size where a mark is a disc. */
function Disc({ size: d = 22 }: { size?: number }) {
  return (
    <div
      style={{
        display: "flex",
        width: d,
        height: d,
        borderRadius: d / 2,
        backgroundColor: DIVIDER,
        flexShrink: 0,
      }}
    />
  );
}

/**
 * One game: two sides stacked, their scores, and the status column a
 * hairline divides off — the app's `GameRow`, abstracted to its shapes.
 *
 * Abstracted deliberately. A marketing graphic carrying "Ohio State 24 –
 * Michigan 21" invents a result, and this card outlives any real one by
 * however long an unfurler caches it. Shapes say "this is a slate" without
 * claiming anything happened. It is the same bargain `GetTheAppCard`'s
 * drawn screen makes, at three times the size.
 */
function GameCard({ live = false }: { live?: boolean }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        backgroundColor: PAPER,
        borderRadius: 12,
        padding: "13px 12px",
        marginTop: 10,
        flexShrink: 0,
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 11, flex: 1 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Disc />
          <Bar w={104} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Disc />
          <Bar w={82} />
        </div>
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-end",
          gap: 11,
          paddingBottom: 0,
        }}
      >
        <Bar w={24} color={INK} />
        <Bar w={24} color={INK} />
      </div>
      <div
        style={{
          display: "flex",
          width: 1,
          height: 46,
          backgroundColor: DIVIDER,
          margin: "0 12px",
          flexShrink: 0,
        }}
      />
      {/* The status column: a live game spends the app's one green on a
          dot, and nothing else on this card is coloured at all. */}
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          width: 56,
          gap: 7,
          flexShrink: 0,
        }}
      >
        {live ? (
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div
              style={{
                display: "flex",
                width: 8,
                height: 8,
                borderRadius: 4,
                backgroundColor: LIVE,
                flexShrink: 0,
              }}
            />
            <Bar w={34} h={9} />
          </div>
        ) : (
          <Bar w={46} h={9} />
        )}
        <Bar w={38} h={9} />
      </div>
    </div>
  );
}

/**
 * The handset, running off the bottom edge of the canvas rather than
 * sitting inside a margin: a device that ends before the frame does reads
 * as a picture *of* a phone, where one that leaves the frame reads as the
 * app carrying on past it.
 */
function Phone() {
  return (
    <div
      style={{
        position: "absolute",
        left: 748,
        top: 92,
        width: 384,
        height: 620,
        display: "flex",
        flexDirection: "column",
        borderRadius: 52,
        border: `2px solid ${DIVIDER}`,
        backgroundColor: RECESSED,
        padding: "0 18px",
      }}
    >
      {/* The speaker slot — the one piece of hardware worth drawing. */}
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          paddingTop: 20,
          paddingBottom: 20,
        }}
      >
        <Bar w={86} h={10} color={DIVIDER} />
      </div>

      {/* The wordmark, in type: the app's own masthead, and the one place
          on this screen where a real string is honest at this size. */}
      <div
        style={{
          display: "flex",
          paddingLeft: 4,
          paddingBottom: 12,
          fontSize: 26,
          fontWeight: 700,
          letterSpacing: -0.6,
          color: INK,
        }}
      >
        StatSide
      </div>

      {/* The controls card: the day strip, today filled the way the
          selected chip inverts. */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 6,
          backgroundColor: PAPER,
          borderRadius: 12,
          padding: 8,
          flexShrink: 0,
        }}
      >
        <div
          style={{
            display: "flex",
            width: 56,
            height: 28,
            borderRadius: 14,
            backgroundColor: RECESSED,
            flexShrink: 0,
          }}
        />
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            height: 28,
            padding: "0 14px",
            borderRadius: 14,
            backgroundColor: INK,
            color: PAPER,
            fontSize: 13,
            fontWeight: 600,
            flexShrink: 0,
          }}
        >
          Today
        </div>
        <div
          style={{
            display: "flex",
            width: 56,
            height: 28,
            borderRadius: 14,
            backgroundColor: RECESSED,
            flexShrink: 0,
          }}
        />
        <div
          style={{
            display: "flex",
            width: 56,
            height: 28,
            borderRadius: 14,
            backgroundColor: RECESSED,
            flexShrink: 0,
          }}
        />
      </div>

      {/* A section header — a league's mark and its name — then its slate. */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          paddingLeft: 4,
          paddingTop: 18,
        }}
      >
        <Disc size={18} />
        <Bar w={86} h={9} color={INK} />
      </div>

      {/* Four, not three: the fourth is entirely below the canvas and
          exists so the third is *interrupted* by the edge rather than
          followed by an inch of empty phone. */}
      <GameCard live />
      <GameCard />
      <GameCard />
      <GameCard />
    </div>
  );
}

export default async function Image() {
  const fonts = await interFonts();

  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          position: "relative",
          width: "100%",
          height: "100%",
          backgroundColor: PAPER,
          fontFamily: "Inter",
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            width: 720,
            padding: "0 0 0 80px",
          }}
        >
          <div
            style={{
              display: "flex",
              fontSize: 96,
              fontWeight: 700,
              letterSpacing: -3,
              color: INK,
            }}
          >
            StatSide
          </div>
          <div
            style={{
              display: "flex",
              marginTop: 18,
              fontSize: 42,
              color: INK,
            }}
          >
            Fast, focused scores.
          </div>
          {/* The league line in the app's own caption language: a quiet
              uppercase tag is how a section header names its league
              (2026-09-07), and spelled out rather than abbreviated because
              a link preview reaches people who don't know "CFB". */}
          <div
            style={{
              display: "flex",
              marginTop: 30,
              fontSize: 23,
              fontWeight: 600,
              letterSpacing: 1.8,
              color: MUTED,
            }}
          >
            COLLEGE FOOTBALL · NFL · NBA · NHL
          </div>
        </div>
        <Phone />
      </div>
    ),
    { ...size, ...(fonts ? { fonts } : {}) }
  );
}
