// The Roster tab's ESPN shapes, mapped — the web twin of the `injuries`,
// `onIce`, `lineup` and `depthChart` mappers in iOS `ESPNMapper` (E29,
// 2026-10-18). Pure, so each one is testable against a capture.

import type { League } from "@/lib/leagues";
import type { DepthSlot, GameInjury, LineupEntry, TeamInjuries } from "@/lib/types";
import type {
  EspnCompetitorRoster,
  EspnDepthCharts,
  EspnOnIceTeam,
  EspnSummaryTeamInjuries,
} from "./types";
import { espnPosition, idFromRef } from "./positions";

function nonEmpty(value: string | number | null | undefined): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value).trim();
  return text.length > 0 ? text : undefined;
}

/** "COACH'S DECISION" → "Coach's decision". */
function sentenceCased(text: string): string {
  const lowered = text.toLowerCase();
  return lowered.charAt(0).toUpperCase() + lowered.slice(1);
}

/**
 * The summary's game-day injury list, per team. A name is required — a row
 * that says "Questionable" about nobody is nothing — and the rest degrades
 * field by field.
 */
export function transformInjuries(teams: EspnSummaryTeamInjuries[]): TeamInjuries[] {
  const result: TeamInjuries[] = [];
  for (const entry of teams) {
    const teamId = nonEmpty(entry.team?.id);
    if (!teamId) continue;
    const injuries: GameInjury[] = [];
    for (const dto of entry.injuries ?? []) {
      const athlete = dto.athlete;
      const name = nonEmpty(athlete?.displayName) ?? nonEmpty(athlete?.fullName);
      if (!athlete || !name) continue;
      // The row's status is ESPN's sentence case ("Injured Reserve");
      // `type.description` is the lowercase code.
      const code = nonEmpty(dto.type?.description);
      const status =
        nonEmpty(dto.status) ?? (code ? code.charAt(0).toUpperCase() + code.slice(1) : "Injured");
      const detail = nonEmpty(dto.details?.type);
      injuries.push({
        id: nonEmpty(athlete.id) ?? `${teamId}-${name}`,
        name,
        jersey: nonEmpty(athlete.jersey),
        position: nonEmpty(athlete.position?.abbreviation),
        headshotUrl: nonEmpty(athlete.headshot?.href),
        status,
        detail: detail && detail.toLowerCase() !== "undisclosed" ? detail : undefined,
        returnDate: nonEmpty(dto.details?.returnDate),
      });
    }
    if (injuries.length > 0) result.push({ teamId, injuries });
  }
  return result;
}

/** Hockey's skaters in play, per team id. Only the "In Play" whereabouts
 *  count: the payload also lists the bench and the box. */
export function transformOnIce(teams: EspnOnIceTeam[]): Record<string, string[]> {
  const result: Record<string, string[]> = {};
  for (const team of teams) {
    const teamId = nonEmpty(team.teamId);
    if (!teamId) continue;
    const ids: string[] = [];
    for (const entry of team.entries ?? []) {
      if (entry.whereabouts?.description?.toLowerCase() !== "in play") continue;
      const id = nonEmpty(entry.athleteid);
      if (id) ids.push(id);
    }
    if (ids.length > 0) result[teamId] = ids;
  }
  return result;
}

/**
 * The core API's game-day roster, one entry per dressed player. The athlete
 * id is the only requirement — it's the join key to the team roster, which
 * carries the name the entry only abbreviates.
 */
export function transformLineup(dto: EspnCompetitorRoster, league: League): LineupEntry[] {
  const entries: LineupEntry[] = [];
  for (const entry of dto.entries ?? []) {
    const athleteId = nonEmpty(entry.playerId);
    if (!athleteId) continue;
    const didNotPlay = entry.didNotPlay ?? false;
    const isScratched = entry.scratched ?? false;
    const reason = nonEmpty(entry.reason) ?? nonEmpty(entry.scratchReason);
    const positionId = idFromRef(entry.position?.$ref, "positions");
    entries.push({
      athleteId,
      shortName: nonEmpty(entry.displayName),
      jersey: nonEmpty(entry.jersey),
      position: positionId ? espnPosition(positionId, league) : undefined,
      isStarter: entry.starter ?? false,
      didNotPlay,
      isScratched,
      // "COACH'S DECISION" and "SCRATCHED" as ESPN shouts them, cased for
      // a row; a scratch with no reason still says so.
      note: reason ? sentenceCased(reason) : isScratched ? "Scratched" : undefined,
      recordedStat: entry.statistics?.$ref !== undefined,
    });
  }
  return entries;
}

/** Every chart's slots, flattened. The NBA and NHL ship one chart; the NFL
 *  ships three and isn't asked. */
export function transformDepthChart(dto: EspnDepthCharts): DepthSlot[] {
  const slots: DepthSlot[] = [];
  for (const chart of dto.items ?? []) {
    // An object's key order is nobody's; the chart's own position ids give
    // the slots a stable one.
    const positions = Object.entries(chart.positions ?? {}).sort(([, a], [, b]) => {
      const left = Number(a.position?.id);
      const right = Number(b.position?.id);
      return (Number.isFinite(left) ? left : Infinity) - (Number.isFinite(right) ? right : Infinity);
    });
    for (const [key, position] of positions) {
      const abbreviation = nonEmpty(position.position?.abbreviation) ?? key.toUpperCase();
      for (const athlete of position.athletes ?? []) {
        const athleteId = idFromRef(athlete.athlete?.$ref, "athletes");
        if (!athleteId || athlete.rank === undefined) continue;
        slots.push({
          position: abbreviation,
          positionName: nonEmpty(position.position?.displayName),
          rank: athlete.rank,
          athleteId,
        });
      }
    }
  }
  return slots;
}
