// The Leagues hub, FotMob-shaped: a Following section first, then every
// league as its own accordion — followed rows repeat inside them, since
// sections stay complete.
//
// The league is an accordion header rather than a segmented control (iOS,
// 2026-09-05): a control shows one league at a time and has to grow a
// segment per sport, while stacked accordions show them all and cost one
// row each. This is also the one screen not scoped to a single league —
// "who's good" has an answer per league, and they fit on one page.
//
// Every fetch fails independently. A league whose standings didn't load has
// no accordion at all, rather than one that's there and empty.

import { hubStandings, rankings } from "@/lib/espn/provider";
import { displayedPolls } from "@/lib/polls";
import { FCS_GROUP_ID } from "@/lib/conferences";
import { LEAGUES, hasPoll, type League } from "@/lib/leagues";
import type { ConferenceStandingsGroup, Poll } from "@/lib/types";
import { LeaguesHub } from "./rankings-hub";

export const revalidate = 300;

async function settled<T>(work: Promise<T>, fallback: T): Promise<T> {
  try {
    return await work;
  } catch {
    return fallback;
  }
}

export default async function LeaguesPage() {
  const [polls, standings, fcs] = await Promise.all([
    // College football is the only league that polls — `/rankings` is a
    // 404 for the other three and always will be.
    settled(rankings("cfb").then(displayedPolls), [] as Poll[]),
    Promise.all(
      LEAGUES.map(async (league) => ({
        league,
        tables: await settled(hubStandings(league), []),
      }))
    ),
    // FCS is a second request against college football's other `groups=`.
    // Separate so either division can fail alone; the *display* folds them
    // into one card (iOS, 2026-09-06).
    settled(hubStandings("cfb", { group: FCS_GROUP_ID }), []),
  ]);

  const byLeague = Object.fromEntries(
    standings.map(({ league, tables }) => [league, tables])
  ) as Record<League, ConferenceStandingsGroup[]>;

  return (
    <LeaguesHub
      polls={polls}
      standings={byLeague}
      fcsStandings={fcs}
      hasAnyPoll={hasPoll("cfb")}
    />
  );
}
