// A team's coaching staff beyond the head coach — the web twin of iOS
// `CoachStaff` (StatSideShared/Models/CoachStaff.swift, 2026-10-03).
//
// ESPN names one coach per team and has no staff endpoint, so the
// coordinators come from `public/coaches.json`, built weekly from Wikipedia
// by `.github/workflows/coaches.yml`. The file is ours and still gets the
// ESPN rule: every field optional, a malformed entry degrades one team's
// list and never the page.

import { leaguePath, type League } from "@/lib/leagues";
import type { RosterCoach } from "@/lib/types";

export interface StaffCoach {
  name: string;
  /** "Offensive coordinator", "Quarterbacks coach" — the file's wording. */
  role: string;
}

/** One line of a team's staff on the game page: the head coach from the
 *  roster payload, then the coordinators from the file, in its order. */
export interface GameCoachLine {
  id: string;
  name: string;
  role: string;
  /** ESPN's coach id — the head coach links to their page (E27); the
   *  coordinators have no ESPN id and don't. */
  coachId?: string;
}

/** The file keys leagues by ESPN's own league segment: "college-football",
 *  "nfl", "nba", "nhl" (iOS `League.pathSegment`). */
export function coachesFileKey(league: League): string {
  return leaguePath(league).split("/").pop() ?? league;
}

/** The staff the file lists for one team, or none. */
export function staffFor(file: unknown, league: League, teamId: string): StaffCoach[] {
  if (typeof file !== "object" || file === null) return [];
  const leagues = (file as { leagues?: unknown }).leagues;
  if (typeof leagues !== "object" || leagues === null) return [];
  const entry = (leagues as Record<string, unknown>)[coachesFileKey(league)];
  if (typeof entry !== "object" || entry === null) return [];
  const team = (entry as Record<string, unknown>)[teamId];
  if (typeof team !== "object" || team === null) return [];
  const staff = (team as { staff?: unknown }).staff;
  if (!Array.isArray(staff)) return [];
  const lines: StaffCoach[] = [];
  for (const member of staff) {
    if (typeof member !== "object" || member === null) continue;
    const { name, role } = member as { name?: unknown; role?: unknown };
    if (typeof name !== "string" || name.trim() === "") continue;
    lines.push({ name: name.trim(), role: typeof role === "string" ? role : "" });
  }
  return lines;
}

export function coachLines(head: RosterCoach | undefined, staff: StaffCoach[]): GameCoachLine[] {
  const lines: GameCoachLine[] = [];
  if (head) {
    lines.push({
      id: `head-${head.id ?? head.name}`,
      name: head.name,
      role: "Head coach",
      coachId: head.id,
    });
  }
  staff.forEach((member, index) => {
    lines.push({ id: `staff-${index}-${member.name}`, name: member.name, role: member.role });
  });
  return lines;
}
