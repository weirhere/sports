// One conference's home — the iOS ConferencePage rebuilt on live data:
// bg-card hero, Standings (default) / Games tabs, seasons back to the 2014
// CFP floor via `?year=`. The server component owns both fetches; the
// client shell owns tab choice only.

import { notFound } from "next/navigation";
import { hubStandings, conferenceGames } from "@/lib/espn";
import { conferenceName } from "@/lib/conferences";
import {
  SEASON_FLOOR,
  displayName,
  parseLeague,
  seasonYear,
  type League,
} from "@/lib/leagues";
import { conferenceCardModel } from "@/lib/og/entity";
import { ConferenceView } from "./conference-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ league: string; conferenceId: string }>;
  searchParams: Promise<{ year?: string | string[]; team?: string | string[] }>;
}

/** A validated season year, or undefined (= the current season). */
function parseYear(
  raw: string | string[] | undefined,
  league: League
): number | undefined {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value || !/^\d{4}$/.test(value)) return undefined;
  const year = Number(value);
  if (year < SEASON_FLOOR || year > seasonYear(league)) return undefined;
  return year;
}

export async function generateMetadata({ params }: PageProps) {
  const { league: leagueParam, conferenceId } = await params;
  const league = parseLeague(leagueParam);
  if (!league) return { title: "Conference | StatSide" };
  const name = conferenceName(Number(conferenceId), league);
  if (name === "Other") {
    return { title: `Conference | ${displayName(league)} | StatSide` };
  }
  return {
    title: `${name} | ${displayName(league)} | StatSide`,
    // See the team page: the unfurl's second line should name the thing
    // the link names, not the site.
    description: conferenceCardModel(league, name, undefined, null)
      .description,
  };
}

export default async function ConferencePage({
  params,
  searchParams,
}: PageProps) {
  const { league: leagueParam, conferenceId } = await params;
  const league = parseLeague(leagueParam);
  if (!league) notFound();
  const numericId = Number(conferenceId);
  // Registry-unknown ids 404 — the registry is the page's whole identity
  // (name, mark, championship-cut gate).
  if (
    !Number.isInteger(numericId) ||
    conferenceName(numericId, league) === "Other"
  ) {
    notFound();
  }

  const sp = await searchParams;
  const currentYear = seasonYear(league);
  const year = parseYear(sp.year, league);
  const fetchYear = year === currentYear ? undefined : year;
  const highlightRaw = Array.isArray(sp.team) ? sp.team[0] : sp.team;
  const highlightTeamId =
    highlightRaw && /^\d+$/.test(highlightRaw) ? highlightRaw : undefined;

  // The divisional response where the league nests, so the scope chip has
  // divisions to show without a second request.
  const [standingsResult, gamesResult] = await Promise.allSettled([
    hubStandings(league, { year: fetchYear }),
    conferenceGames(league, numericId, fetchYear),
  ]);

  const allTables =
    standingsResult.status === "fulfilled" ? standingsResult.value : null;
  const games = gamesResult.status === "fulfilled" ? gamesResult.value : null;

  return (
    <ConferenceView
      league={league}
      conferenceId={numericId}
      name={conferenceName(numericId, league)}
      allTables={allTables}
      games={games}
      displayYear={year ?? currentYear}
      highlightTeamId={highlightTeamId}
    />
  );
}
