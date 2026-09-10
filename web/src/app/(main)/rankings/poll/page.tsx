// The Top 25 as an **entity page** (iOS PollScreen, 2026-09-05): the
// ConferencePage/TeamPage template, because the Top 25 *is* an entity whose
// members are 25 teams. Standings is the poll table, Games is those teams'
// season slate, and the postseason bracket appears once a season has one.
//
// Which poll is a filter, not a tab: AP, Coaches and CFP are the same table
// of the same 25 teams read by different voters.

import { rankings, seasonGames } from "@/lib/espn";
import { displayedPolls } from "@/lib/polls";
import {
  SEASON_FLOOR,
  seasonYear,
  type League,
} from "@/lib/leagues";
import type { Game, Poll } from "@/lib/types";
import { PollView } from "./poll-view";

export const dynamic = "force-dynamic";

const LEAGUE: League = "cfb";

export const metadata = {
  title: "Top 25 | College Football | StatSide",
};

interface PageProps {
  searchParams: Promise<{ year?: string | string[] }>;
}

function parseYear(raw: string | string[] | undefined): number | undefined {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value || !/^\d{4}$/.test(value)) return undefined;
  const year = Number(value);
  if (year < SEASON_FLOOR || year > seasonYear(LEAGUE)) return undefined;
  return year;
}

export default async function PollPage({ searchParams }: PageProps) {
  const currentYear = seasonYear(LEAGUE);
  const year = parseYear((await searchParams).year) ?? currentYear;

  // The poll and the slate fail independently: a season with no poll still
  // has games, and a slate that missed still leaves a table to read.
  const [pollResult, gamesResult] = await Promise.allSettled([
    rankings(LEAGUE, year),
    seasonGames(LEAGUE, year),
  ]);

  const polls: Poll[] | null =
    pollResult.status === "fulfilled" ? displayedPolls(pollResult.value) : null;
  const games: Game[] | null =
    gamesResult.status === "fulfilled" ? gamesResult.value : null;

  return (
    <PollView
      league={LEAGUE}
      polls={polls}
      games={games}
      displayYear={year}
    />
  );
}
