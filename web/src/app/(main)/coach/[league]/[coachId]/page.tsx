// One head coach's page — iOS `CoachPage` (Features/Coaches/, E27,
// 2026-09-27): Profile, Career and Games. The server component owns the
// career walk; the client view owns tab choice and the Games tab's fetch.
//
// **One league per page.** ESPN keys coaches per league with nothing joining
// them, so the URL carries the league and the career is that league's.

import { notFound } from "next/navigation";
import { coachCareer } from "@/lib/espn/coach";
import { displayName, parseLeague } from "@/lib/leagues";
import { CoachView } from "./coach-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ league: string; coachId: string }>;
  searchParams: Promise<{ team?: string | string[] }>;
}

/** The roster's team, when the link carried one: a stand-in for the badge. */
async function fallbackTeam(searchParams: PageProps["searchParams"]): Promise<string | undefined> {
  const { team } = await searchParams;
  return typeof team === "string" && /^\d+$/.test(team) ? team : undefined;
}

export async function generateMetadata({ params, searchParams }: PageProps) {
  const { league: leagueParam, coachId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(coachId)) return { title: "Coach | StatSide" };
  // The page's own request: Next memoizes a render's identical fetches.
  const career = await coachCareer(league, coachId, await fallbackTeam(searchParams));
  return {
    title: career?.profile.name
      ? `${career.profile.name} | ${displayName(league)} | StatSide`
      : `Coach | ${displayName(league)} | StatSide`,
  };
}

export default async function CoachPage({ params, searchParams }: PageProps) {
  const { league: leagueParam, coachId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(coachId)) notFound();

  const career = await coachCareer(league, coachId, await fallbackTeam(searchParams));
  if (!career || !career.profile.name) notFound();

  return <CoachView league={league} career={career} />;
}
