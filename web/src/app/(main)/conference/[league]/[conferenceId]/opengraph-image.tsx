// The graphic a conference link wears when it's pasted into Slack, posted
// on X, or sent anywhere that unfurls a URL — the page's own hero at
// poster size: the mark, the name, and how many teams are in it.
//
// The identity costs **no request at all**: a conference's name and mark
// both come off the registry, which is the page's own source for them. The
// one fetch is the standings, and it buys exactly one line — "18 teams" —
// so it is allowed to fail into a card with no subtitle rather than into
// no card.
//
// The mark wears no backing disc. The disc is a dark-mode device (navy
// marks sinking into black), and this card is always light, where the
// backing token is transparent anyway.

import { ImageResponse } from "next/og";
import { hubStandings } from "@/lib/espn";
import { conferenceLogoUrl, conferenceName } from "@/lib/conferences";
import { tablesAtScope } from "@/lib/standings-tables";
import { displayName, parseLeague } from "@/lib/leagues";
import { BrandCard, EntityCard, OG_SIZE } from "@/lib/og/card";
import { conferenceCardModel } from "@/lib/og/entity";
import { interFonts } from "@/lib/og/fonts";
import { logoData } from "@/lib/og/logo";

export const alt = "StatSide conference card";
export const size = OG_SIZE;
export const contentType = "image/png";

export default async function Image({
  params,
}: {
  params: Promise<{ league: string; conferenceId: string }>;
}) {
  const { league: leagueParam, conferenceId } = await params;
  const league = parseLeague(leagueParam);
  const fonts = await interFonts();
  const options = { ...size, ...(fonts ? { fonts } : {}) };
  const tagline = league ? `${displayName(league)} scores` : "Live scores";

  const id = Number(conferenceId);
  // The same gate the page itself keeps: the registry is a conference
  // page's whole identity, so an id it can't name has no card to draw.
  if (!league || !Number.isInteger(id) || conferenceName(id, league) === "Other") {
    return new ImageResponse(<BrandCard tagline={tagline} />, options);
  }

  const name = conferenceName(id, league);
  // The count sums every division, however the tables are sliced — the
  // hero's own rule.
  const tables = await hubStandings(league)
    .then((groups) => tablesAtScope(groups, { id, league }, "conference"))
    .catch(() => null);

  const model = conferenceCardModel(
    league,
    name,
    conferenceLogoUrl(id, league),
    tables
  );
  return new ImageResponse(
    <EntityCard
      kicker={model.kicker}
      logo={await logoData(model.logoUrl)}
      title={model.title}
      subtitle={model.subtitle}
    />,
    options
  );
}
