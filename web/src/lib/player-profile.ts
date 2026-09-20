// The player page's facts, taken from the roster row that links to it — the
// web twin of iOS `PlayerIdentity` (StatSideShared/Models/Player.swift).
//
// **Nothing here is fetched from an athlete endpoint**, because there isn't
// one we've proved out (E20's P0, `scripts/probe-athlete.sh`). A roster row
// already holds every fact the Profile tab prints, which is why the roster is
// the one door open in this first cut.
//
// The one real difference from iOS: a URL has to rebuild the page from
// nothing on a cold load — someone shares the link, or hits refresh — and the
// roster endpoint is the only thing that knows this player. It is addressed
// by team, so the team id rides in the path. iOS carries the facts in memory
// through the navigation destination and needs no such thing.

import type { League } from "./leagues";
import { rosterMetric, spokenMetric } from "./roster-metric";
import type { RosterPlayer, TeamRoster } from "./types";

export interface PlayerProfileRow {
  label: string;
  value: string;
}

/** Where a roster row points. */
export function playerHref(
  league: League,
  teamId: string,
  athleteId: string
): string {
  return `/player/${league}/${teamId}/${athleteId}`;
}

/**
 * The hero's second line — team · #11 · QB. Each part drops out on its own,
 * so a player ESPN knows little about is a name rather than a line of
 * orphaned separators.
 */
export function playerMetaLine(
  player: RosterPlayer,
  teamName?: string
): string {
  return [
    teamName,
    player.jersey ? `#${player.jersey}` : undefined,
    player.position,
  ]
    .filter((part): part is string => Boolean(part))
    .join(" · ");
}

/**
 * Profile's label/value pairs, in the design's order, skipping whatever ESPN
 * didn't send rather than printing a dash.
 *
 * The third row is the league's own, for `rosterMetric`'s reason: college
 * football publishes no age at all and a class year instead, so an Age row
 * there would label a value that never arrives.
 *
 * **No hometown row.** The design draws one; no payload we hold carries a
 * `birthPlace`, and the fixtures are trimmed, so its source is unknown rather
 * than absent. The row lands when the probe finds it.
 */
export function playerProfileRows(
  player: RosterPlayer,
  league: League
): PlayerProfileRow[] {
  const rows: PlayerProfileRow[] = [];
  if (player.height) rows.push({ label: "Height", value: player.height });
  if (player.weight) rows.push({ label: "Weight", value: player.weight });

  const metric = rosterMetric(league);
  if (metric.field === "age") {
    if (player.age !== undefined) {
      rows.push({ label: "Age", value: String(player.age) });
    }
  } else if (player.classAbbreviation) {
    // `spokenMetric` maps the four known abbreviations and passes anything
    // else straight back, so capitalizing blindly would spell "GR" as "Gr".
    const spoken = spokenMetric(player.classAbbreviation, metric);
    rows.push({
      label: "Class",
      value:
        spoken === player.classAbbreviation
          ? player.classAbbreviation
          : spoken.charAt(0).toUpperCase() + spoken.slice(1),
    });
  }

  if (player.positionName) {
    rows.push({ label: "Position", value: player.positionName });
  }
  if (player.jersey) rows.push({ label: "Jersey", value: player.jersey });
  if (player.injuryStatus) {
    rows.push({ label: "Status", value: player.injuryStatus });
  }
  return rows;
}

/**
 * One sentence for the hero, so a screen reader doesn't read a name and then
 * an unlabelled run of abbreviations — `rosterSentence`'s rule, and the
 * position is spoken in full because "QB" is read as letters.
 */
export function playerSpokenSummary(
  player: RosterPlayer,
  teamName?: string
): string {
  const parts: string[] = [player.name];
  if (teamName) parts.push(teamName);
  if (player.jersey) parts.push(`number ${player.jersey}`);
  const position = player.positionName ?? player.position;
  if (position) parts.push(position);
  return parts.join(", ");
}

/**
 * The player this URL names, or undefined. Searched across every group
 * because the grouping is ESPN's and a player belongs to exactly one of
 * them — the route knows an athlete id and nothing about squads.
 */
export function findRosterPlayer(
  roster: TeamRoster,
  athleteId: string
): RosterPlayer | undefined {
  for (const group of roster.groups) {
    const hit = group.players.find((player) => player.id === athleteId);
    if (hit) return hit;
  }
  return undefined;
}
