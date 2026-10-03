// One head coach's career from ESPN's core API — the web twin of iOS
// `CoachClient` (StatSideShared/Networking/, E27, 2026-09-27).
//
// The person record (`leagues/{league}/coaches/{id}`) carries the bio, the
// career records and one `coachSeasons` ref per season in the job. Each
// season is two requests — the season, for its team, and its record, whose
// path is derivable so both go out together — plus one per distinct team for
// its name and mark. Bowles is ~26 requests, Carlisle's 24 NBA seasons ~55,
// all in parallel and cached for a day: past seasons don't change.
//
// Every piece degrades. A season whose team can't be read is dropped, a
// record that 404s leaves its row out; only a person that won't load
// answers null, which is the page's 404.

import { espnSeason, leagueSpec, type League } from "@/lib/leagues";
import {
  careerRecords,
  cleanedSeasons,
  coachProfile,
  coachRecord,
  coachSeasons,
  seasonYearInRef,
  type CoachCareer,
  type CoachRecord,
  type CoachSeason,
  type CoachTeamLabel,
  type EspnCoachPerson,
  type EspnCoachRecord,
  type EspnCoachSeason,
} from "@/lib/coach";

const REVALIDATE = 86400;

function leagueBase(league: League): string {
  const { sportSegment, pathSegment } = leagueSpec(league);
  return `https://sports.core.api.espn.com/v2/sports/${sportSegment}/leagues/${pathSegment}`;
}

/** The core API's refs are `http://`; the same document answers over https. */
async function fetchOrNull<T>(url: string | undefined): Promise<T | null> {
  if (!url) return null;
  try {
    const res = await fetch(url.replace(/^http:\/\//, "https://"), {
      next: { revalidate: REVALIDATE },
    });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

interface EspnCoreTeam {
  displayName?: string;
  name?: string;
  abbreviation?: string;
  logos?: { href?: string }[];
}

export async function coachCareer(
  league: League,
  coachId: string,
  fallbackTeamId?: string
): Promise<CoachCareer | null> {
  const base = leagueBase(league);
  const person = await fetchOrNull<EspnCoachPerson>(`${base}/coaches/${coachId}`);
  if (!person) return null;

  const [records, college, seasons] = await Promise.all([
    Promise.all(
      (person.careerRecords ?? []).map(async (ref) => {
        const dto = await fetchOrNull<EspnCoachRecord>(ref.$ref);
        return dto ? coachRecord(dto, league) : undefined;
      })
    ),
    fetchOrNull<{ name?: string; shortName?: string }>(person.college?.$ref),
    loadSeasons(league, coachId, person),
  ]);

  const profile = coachProfile(person);
  profile.records = careerRecords(records.filter((r): r is CoachRecord => r !== undefined));
  profile.college = college?.name ?? college?.shortName;
  profile.seasons = seasons;
  const teams = await teamLabels(league, seasons);
  // The hero's badge. A coach in their first season (Marco Sturm, hired
  // 2025) has no seasons to have named the team, and the person record
  // carries no `team` either — so the team the link came from stands in,
  // and is asked for by id.
  profile.currentTeamId ??= fallbackTeamId;
  const current = profile.currentTeamId;
  if (current && !teams[current]) {
    const label = await teamLabel(`${base}/teams/${current}`);
    if (label) teams[current] = label;
  }
  return { profile, teams };
}

async function teamLabel(url: string): Promise<CoachTeamLabel | undefined> {
  const dto = await fetchOrNull<EspnCoreTeam>(url);
  const name = dto?.displayName ?? dto?.name;
  if (!name) return undefined;
  return { name, abbreviation: dto?.abbreviation, logoUrl: dto?.logos?.[0]?.href };
}

async function loadSeasons(
  league: League,
  coachId: string,
  person: EspnCoachPerson
): Promise<CoachSeason[]> {
  const base = leagueBase(league);
  const years = [
    ...new Set(
      (person.coachSeasons ?? [])
        .map((ref) => seasonYearInRef(ref.$ref))
        .filter((year): year is number => year !== undefined)
    ),
  ];
  const rows = await Promise.all(
    years.map(async (espnYear) => {
      const [season, record] = await Promise.all([
        fetchOrNull<EspnCoachSeason>(`${base}/seasons/${espnYear}/coaches/${coachId}`),
        fetchOrNull<EspnCoachRecord>(
          `${base}/seasons/${espnYear}/types/2/coaches/${coachId}/record`
        ),
      ]);
      return coachSeasons(season, espnYear, record ? coachRecord(record, league) : undefined, league);
    })
  );
  return cleanedSeasons(rows.flat());
}

/** Each team as the core API names it in the newest season the coach was
 *  there, so a rebrand reads as the name they last worked under. */
async function teamLabels(
  league: League,
  seasons: CoachSeason[]
): Promise<Record<string, CoachTeamLabel>> {
  const base = leagueBase(league);
  const newest = new Map<string, number>();
  for (const season of seasons) if (!newest.has(season.teamId)) newest.set(season.teamId, season.year);
  const entries = await Promise.all(
    [...newest].map(async ([teamId, year]) => {
      const label = await teamLabel(`${base}/seasons/${espnSeason(league, year)}/teams/${teamId}`);
      return label ? ([teamId, label] as const) : undefined;
    })
  );
  return Object.fromEntries(entries.filter((e) => e !== undefined));
}
