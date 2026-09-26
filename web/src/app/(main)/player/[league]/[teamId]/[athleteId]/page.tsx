// One player's page. The server component owns every fetch but the game
// log, which waits for the Games tab; the client view owns tab choice.
//
// **Three requests, in parallel.** The team's roster (the row that linked
// here, and college football's class year), ESPN's athlete profile (the
// team, and the facts a roster no longer holds), and the athlete's stats
// (the This season card, and the Stats and Career tabs — which the page
// draws either way, with empty states when ESPN has no line). All three are keyed off
// the path, so a shared link or a refresh rebuilds the same page.
//
// **Why the team id is still in the URL.** It addresses the roster, which
// the athlete payload can't replace: college football's class year lives
// only there. It no longer names the team — the athlete payload does, since
// "one player page, whichever door opened it" (2026-09-21) — so a link
// carrying a team the player has since left still opens his page, badged
// with the club he plays for now.

import { notFound } from "next/navigation";
import { teamRoster, teamSchedule } from "@/lib/espn";
import { athleteProfile, athleteStats } from "@/lib/espn/athlete";
import {
  displayName,
  espnSeason,
  parseLeague,
  seasonYearContaining,
  type League,
} from "@/lib/leagues";
import { findRosterPlayer, mergePlayer } from "@/lib/player-profile";
import { PlayerView } from "./player-view";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ league: string; teamId: string; athleteId: string }>;
}

/** The player the path names, from whichever source answered. */
async function resolvePlayer(league: League, teamId: string, athleteId: string) {
  const [rosterResult, athlete] = await Promise.all([
    // No year: ESPN's roster endpoint has no season axis, so this is the
    // current roster whatever else the site is showing.
    teamRoster(league, teamId).then(
      (roster) => findRosterPlayer(roster, athleteId),
      () => undefined
    ),
    athleteProfile(league, athleteId),
  ]);
  return { player: mergePlayer(athleteId, rosterResult, athlete), athlete };
}

export async function generateMetadata({ params }: PageProps) {
  const { league: leagueParam, teamId, athleteId } = await params;
  const league = parseLeague(leagueParam);
  if (!league) return { title: "Player | StatSide" };
  // The page's own requests: Next memoizes a render's identical fetches,
  // so this costs nothing the page wasn't going to pay.
  const { player } = await resolvePlayer(league, teamId, athleteId);
  return {
    title: player
      ? `${player.name} | ${displayName(league)} | StatSide`
      : `Player | ${displayName(league)} | StatSide`,
  };
}

export default async function PlayerPage({ params }: PageProps) {
  const { league: leagueParam, teamId, athleteId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(teamId) || !/^\d+$/.test(athleteId)) notFound();

  const [{ player, athlete }, stats] = await Promise.all([
    resolvePlayer(league, teamId, athleteId),
    athleteStats(league, athleteId),
  ]);
  // Neither source knows him — a dead link, or ESPN down on both hosts.
  if (!player) notFound();

  // The badge names the team off the fetched team, never off the path. Only
  // when the athlete fetch failed outright does the path's team stand in,
  // through the schedule fetch the page made before the athlete endpoint
  // was proved out — the roster fallback's other half. An athlete payload
  // with no team is a free agent, and gets no badge rather than his old one.
  let team: { id: string; name?: string; logoUrl?: string } | undefined;
  if (athlete) {
    if (athlete.teamId) {
      team = { id: athlete.teamId, name: athlete.teamName, logoUrl: athlete.teamLogoUrl };
    }
  } else {
    const schedule = await teamSchedule(league, teamId).catch(() => undefined);
    if (schedule?.team) {
      team = { id: teamId, name: schedule.team.school, logoUrl: schedule.team.logoUrl };
    }
  }

  return (
    <PlayerView
      league={league}
      athleteId={athleteId}
      player={player}
      team={team?.name ? team : undefined}
      stats={stats}
      // The season "now" belongs to, on the app-wide clock and in ESPN's
      // numbering for this league — the only season the This season card
      // will speak for. Decided here so server and client agree.
      currentEspnSeason={espnSeason(league, seasonYearContaining(new Date()))}
    />
  );
}
