// The player page's facts — the web twin of iOS `PlayerIdentity`
// (StatSideShared/Models/Player.swift).
//
// **Two sources, roster first.** The team's roster row and ESPN's own athlete
// endpoint (`common/v3/.../athletes/{id}` on `site.web.api.espn.com`, see
// `src/lib/espn/athlete.ts`). This header used to say no athlete endpoint had
// been proved out; one was on 2026-09-21, and it is what names the team and
// fills a page the roster can't. The roster still wins wherever both answer
// — it carries college football's class year, which the athlete payload
// doesn't — and it is the fallback when the athlete fetch fails.
//
// The one real difference from iOS: a URL has to rebuild the page from
// nothing on a cold load — someone shares the link, or hits refresh. iOS
// carries the door's facts in memory; the web re-fetches both sources from
// the path, which is why the team id still rides in it.

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
 * One sentence for the hero: name and club, which is exactly what the hero
 * draws (2026-09-21).
 *
 * It used to speak the number and the position too, from the days when the
 * hero printed them. They are Profile rows now, and so is their spoken form
 * — a label that announces facts the screen doesn't show makes the page
 * longer to hear than to read, and the rows below say both with their own
 * names attached.
 */
export function playerSpokenSummary(
  player: RosterPlayer,
  teamName?: string
): string {
  const parts: string[] = [player.name];
  if (teamName) parts.push(teamName);
  return parts.join(", ");
}

/**
 * What ESPN's athlete endpoint says about a player — `transformAthleteProfile`
 * in `src/lib/espn/athlete.ts`. Every field optional: a walk-on can come back
 * with a name and nothing else.
 */
export interface AthleteProfile {
  name?: string;
  age?: number;
  jersey?: string;
  position?: string;
  positionName?: string;
  height?: string;
  weight?: string;
  headshotUrl?: string;
  injuryStatus?: string;
  /** The club ESPN has him on today — the hero badge's destination. */
  teamId?: string;
  /** `displayName ?? location`, the app's one team name. */
  teamName?: string;
  teamLogoUrl?: string;
}

/**
 * The player the page renders: the roster row where there is one, with
 * whatever the athlete endpoint adds filling its gaps — iOS
 * `AthleteProfileClient.filling(_:)`'s `x ?? athlete.x`, field by field.
 *
 * Either source alone is enough. A roster that no longer lists him (a
 * trade, a box score from a past season) still has the athlete payload; an
 * athlete fetch that failed still has the roster. Neither — or a payload
 * with no name to put on the page — is undefined, which is a 404.
 */
export function mergePlayer(
  athleteId: string,
  rosterPlayer: RosterPlayer | undefined,
  athlete: AthleteProfile | undefined
): RosterPlayer | undefined {
  const name = rosterPlayer?.name ?? athlete?.name;
  if (!name) return undefined;
  const base: RosterPlayer = rosterPlayer ?? { id: athleteId, name };
  if (!athlete) return base;
  return {
    ...base,
    jersey: base.jersey ?? athlete.jersey,
    position: base.position ?? athlete.position,
    positionName: base.positionName ?? athlete.positionName,
    height: base.height ?? athlete.height,
    weight: base.weight ?? athlete.weight,
    age: base.age ?? athlete.age,
    headshotUrl: base.headshotUrl ?? athlete.headshotUrl,
    injuryStatus: base.injuryStatus ?? athlete.injuryStatus,
  };
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
