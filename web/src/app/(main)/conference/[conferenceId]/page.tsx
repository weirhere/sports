// One conference's home — the iOS ConferencePage rebuilt on live data:
// bg-card hero, Standings (default) / Games tabs, seasons back to the 2014
// CFP floor via `?year=`. The server component owns both fetches; the
// client shell owns tab choice only.

import { notFound } from "next/navigation";
import { conferenceStandings, conferenceGames } from "@/lib/espn";
import { conferenceName } from "@/lib/conferences";
import { cfbSeasonYear } from "@/lib/season";
import { ConferenceView } from "./conference-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ conferenceId: string }>;
  searchParams: Promise<{ year?: string | string[]; team?: string | string[] }>;
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
  const { conferenceId } = await params;
  const name = conferenceName(Number(conferenceId));
  return {
    title:
      name !== "Other"
        ? `${name} | College Football Hub`
        : "Conference | College Football Hub",
  };
}

export default async function ConferencePage({
  params,
  searchParams,
}: PageProps) {
  const { conferenceId } = await params;
  const numericId = Number(conferenceId);
  // Registry-unknown ids 404 — the registry is the page's whole identity
  // (name, mark, championship-cut gate).
  if (!Number.isInteger(numericId) || conferenceName(numericId) === "Other") {
    notFound();
  }

  const sp = await searchParams;
  const currentYear = cfbSeasonYear();
  const year = parseYear(sp.year);
  const fetchYear = year === currentYear ? undefined : year;
  const highlightRaw = Array.isArray(sp.team) ? sp.team[0] : sp.team;
  const highlightTeamId =
    highlightRaw && /^\d+$/.test(highlightRaw) ? highlightRaw : undefined;

  const [standingsResult, gamesResult] = await Promise.allSettled([
    conferenceStandings(fetchYear),
    conferenceGames(numericId, fetchYear),
  ]);

  const group =
    standingsResult.status === "fulfilled"
      ? (standingsResult.value.find((g) => g.id === String(numericId)) ?? {
          id: String(numericId),
          name: conferenceName(numericId),
          entries: [],
        })
      : null;
  const games = gamesResult.status === "fulfilled" ? gamesResult.value : null;

  return (
    <ConferenceView
      conferenceId={numericId}
      name={conferenceName(numericId)}
      standings={group}
      games={games}
      displayYear={year ?? currentYear}
      highlightTeamId={highlightTeamId}
    />
  );
}
