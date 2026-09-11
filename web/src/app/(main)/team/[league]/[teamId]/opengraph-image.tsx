// The graphic a team link wears when it's pasted into Slack, posted on X,
// or sent anywhere that unfurls a URL.
//
// Before this, a team page inherited the site's brand card — right for
// Leagues or Search, and a wasted answer here: the link names a team, so
// the card should too. It is the page's own hero at poster size (mark,
// name, conference · record) on the shared chassis, so a team link and a
// game link arrive in a thread looking like the same product.
//
// Two rules, inherited from the game card:
//   1. It must never fail. An unfurler that gets a 500 shows no image at
//      all and caches that nothing — so a missing mark degrades to a quiet
//      disc, a missing font to the default, and an unknown team id to the
//      brand card.
//   2. It must never invent. A team that hasn't played carries no record.
//
// One request, deliberately. The schedule payload already holds the
// identity *and* the record; a rank badge would cost a second fetch for a
// number that freezes the moment an unfurler caches the image.

import { ImageResponse } from "next/og";
import { teamSchedule } from "@/lib/espn";
import { displayName, parseLeague } from "@/lib/leagues";
import { BrandCard, EntityCard, OG_SIZE } from "@/lib/og/card";
import { teamCardModel } from "@/lib/og/entity";
import { interFonts } from "@/lib/og/fonts";
import { logoData } from "@/lib/og/logo";

export const alt = "StatSide team card";
export const size = OG_SIZE;
export const contentType = "image/png";

export default async function Image({
  params,
}: {
  params: Promise<{ league: string; teamId: string }>;
}) {
  const { league: leagueParam, teamId } = await params;
  const league = parseLeague(leagueParam);
  const fonts = await interFonts();
  const options = { ...size, ...(fonts ? { fonts } : {}) };
  // The fallback names whatever league the URL claimed — it renders when
  // the fetch failed, which says nothing about the league.
  const tagline = league ? `${displayName(league)} scores` : "Live scores";

  if (!league) return new ImageResponse(<BrandCard tagline={tagline} />, options);

  try {
    const schedule = await teamSchedule(league, teamId);
    if (!schedule.team) {
      return new ImageResponse(<BrandCard tagline={tagline} />, options);
    }
    const model = teamCardModel(league, schedule);
    return new ImageResponse(
      <EntityCard
        kicker={model.kicker}
        logo={await logoData(model.logoUrl)}
        title={model.title}
        subtitle={model.subtitle}
      />,
      options
    );
  } catch {
    return new ImageResponse(<BrandCard tagline={tagline} />, options);
  }
}
