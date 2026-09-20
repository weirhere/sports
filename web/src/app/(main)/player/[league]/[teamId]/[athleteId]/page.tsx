// One player's page. The server component owns every fetch; the client view
// owns nothing but a broken-image fallback.
//
// **Why the team id is in the URL.** iOS carries a player's facts in memory
// through its navigation destination, so it needs no identifier but the
// athlete's. A URL has to rebuild the page from nothing — a shared link, a
// refresh, a crawler — and there is no athlete endpoint to rebuild it from
// (E20's P0, unanswered). The roster endpoint is the only thing that knows
// this player, and it is addressed by team, so the team id rides in the path
// and the page finds the athlete inside the roster it already knows how to
// fetch. One request, no new endpoint, and the link survives being shared.

import { notFound } from "next/navigation";
import { teamRoster, teamSchedule } from "@/lib/espn";
import { displayName, parseLeague } from "@/lib/leagues";
import { findRosterPlayer } from "@/lib/player-profile";
import { PlayerView } from "./player-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ league: string; teamId: string; athleteId: string }>;
}

export async function generateMetadata({ params }: PageProps) {
  const { league: leagueParam, teamId, athleteId } = await params;
  const league = parseLeague(leagueParam);
  if (!league) return { title: "Player | StatSide" };
  try {
    const roster = await teamRoster(league, teamId);
    const player = findRosterPlayer(roster, athleteId);
    return {
      title: player
        ? `${player.name} | ${displayName(league)} | StatSide`
        : `Player | ${displayName(league)} | StatSide`,
    };
  } catch {
    return { title: "Player | StatSide" };
  }
}

export default async function PlayerPage({ params }: PageProps) {
  const { league: leagueParam, teamId, athleteId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(teamId) || !/^\d+$/.test(athleteId)) notFound();

  const [rosterResult, scheduleResult] = await Promise.allSettled([
    // No year: ESPN's roster endpoint has no season axis, so this is the
    // current roster whatever else the site is showing.
    teamRoster(league, teamId),
    // Only for the crest and the school name in the hero. A failure here
    // costs the page its team line and nothing else, which is why it is
    // settled separately rather than awaited together.
    teamSchedule(league, teamId),
  ]);

  // A dead roster fetch and a team ESPN has no roster for look the same from
  // here, and both mean there is no player to render.
  if (rosterResult.status === "rejected") notFound();
  const player = findRosterPlayer(rosterResult.value, athleteId);
  if (!player) notFound();

  const team =
    scheduleResult.status === "fulfilled" ? scheduleResult.value.team : undefined;

  return (
    <PlayerView
      league={league}
      player={player}
      teamId={teamId}
      teamName={team?.school}
      teamLogoUrl={team?.logoUrl}
    />
  );
}
