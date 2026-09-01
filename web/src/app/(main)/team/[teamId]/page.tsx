// One team's home — the iOS TeamPage rebuilt on live data: bg-card hero,
// Overview / Games / Standings tabs, seasons back to the 2014 CFP floor via
// `?year=`. The server component owns every fetch (the provider is the
// per-year cache); the client shell owns tab choice only.

import { notFound } from "next/navigation";
import {
  teamSchedule,
  conferenceStandings,
  rankings,
} from "@/lib/espn";
import { cfbSeasonYear } from "@/lib/season";
import { TeamView } from "./team-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ teamId: string }>;
  searchParams: Promise<{ year?: string | string[] }>;
}

/** A validated season year, or undefined (= the current season). */
function parseYear(raw: string | string[] | undefined): number | undefined {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value || !/^\d{4}$/.test(value)) return undefined;
  const year = Number(value);
  if (year < 2014 || year > cfbSeasonYear()) return undefined;
  return year;
}

export async function generateMetadata({ params }: PageProps) {
  const { teamId } = await params;
  try {
    const schedule = await teamSchedule(teamId);
    const school = schedule.team?.school;
    return {
      title: school
        ? `${school} | College Football Hub`
        : "Team | College Football Hub",
    };
  } catch {
    return { title: "Team | College Football Hub" };
  }
}

export default async function TeamPage({ params, searchParams }: PageProps) {
  const { teamId } = await params;
  if (!/^\d+$/.test(teamId)) notFound();

  const currentYear = cfbSeasonYear();
  const year = parseYear((await searchParams).year);
  // Nil for the current season keeps the shipped request shape (and the
  // provider's unpublished-season fallback); an explicit past year is
  // scoped exactly — a user who picked 2019 must never silently get 2018.
  const fetchYear = year === currentYear ? undefined : year;

  const [scheduleResult, standingsResult, rankingsResult] =
    await Promise.allSettled([
      teamSchedule(teamId, fetchYear),
      conferenceStandings(fetchYear),
      rankings(),
    ]);

  // Unknown team: no identity and no games. A dead ESPN response for the
  // schedule looks the same from here — there is nothing to render a hero
  // from either way.
  if (scheduleResult.status === "rejected") notFound();
  const schedule = scheduleResult.value;
  if (!schedule.team && schedule.games.length === 0) notFound();

  const standingsGroups =
    standingsResult.status === "fulfilled" ? standingsResult.value : null;

  // Rank badge: the current AP top 25 (rankings are always current-season).
  const polls = rankingsResult.status === "fulfilled" ? rankingsResult.value : [];
  const apPoll = polls.find((poll) => poll.type === "ap") ?? polls[0];
  const apRank = apPoll?.ranks.find((rank) => rank.team.id === teamId)?.rank;

  return (
    <TeamView
      teamId={teamId}
      schedule={schedule}
      standingsGroups={standingsGroups}
      apRank={apRank}
      // The payload's own year pins the chip label — the current-season
      // fetch may fall back a season while the next one is unpublished.
      displayYear={schedule.year ?? year ?? currentYear}
      isCurrentSeason={(year ?? currentYear) === currentYear}
    />
  );
}
