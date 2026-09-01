// The Rankings hub, FotMob-Leagues-shaped (iOS RankingsScreen): a Following
// section first (the Top 25 row, then followed conferences), then the
// complete All conferences list — followed rows repeat there, since
// sections stay complete, never deduplicated.

import { rankings, conferenceStandings } from "@/lib/espn/provider";
import { displayedPolls } from "@/lib/polls";
import type { ConferenceStandingsGroup, Poll } from "@/lib/types";
import { RankingsHub } from "./rankings-hub";

export default async function RankingsPage() {
  // The two fetches fail independently: no poll is a screen-level error
  // only when there are no conferences either; a standings miss just hides
  // the conference rows under a healthy Top 25 row.
  const [pollsResult, standingsResult] = await Promise.allSettled([
    rankings(),
    conferenceStandings(),
  ]);
  const polls: Poll[] =
    pollsResult.status === "fulfilled"
      ? displayedPolls(pollsResult.value)
      : [];
  const conferences: ConferenceStandingsGroup[] | null =
    standingsResult.status === "fulfilled" ? standingsResult.value : null;

  return <RankingsHub polls={polls} conferences={conferences} />;
}
