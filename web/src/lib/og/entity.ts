// What a team's or a conference's link preview says — every string in one
// pure function, so the unfurl's copy is testable without rendering a
// 1200×630 PNG. The game card's `og-card.ts` set the pattern; this is its
// sibling for the entity pages.
//
// Both cards mirror the page's own hero: mark, name, and the one line of
// context the hero carries (a team's conference, a conference's size).
// What the hero never has to say is which league it belongs to — you got
// there through one — so the card adds that as a kicker above the name.

import { conferenceName } from "@/lib/conferences";
import { displayName, type League } from "@/lib/leagues";
import type { ConferenceStandingsGroup, TeamScheduleData } from "@/lib/types";

export interface EntityCardModel {
  /**
   * The league, above the name: "COLLEGE FOOTBALL", "NHL". Absent where it
   * would only repeat the name — a league's own whole-league table is a
   * page called "NFL" inside the NFL.
   */
  kicker?: string;
  /** The entity's name — the card's headline. */
  title: string;
  /** One line beneath: "Big Ten · 7-1", "18 teams". */
  subtitle?: string;
  logoUrl?: string;
  /** The image's alt text, for readers whose client shows it. */
  alt: string;
  /** og:description — stable on purpose; see `describeTeam`. */
  description: string;
}

/** The registry's name for an id, or undefined where it has none. */
function namedConference(
  conferenceId: string | undefined,
  league: League
): string | undefined {
  if (conferenceId === undefined || conferenceId === "") return undefined;
  const id = Number(conferenceId);
  if (!Number.isInteger(id)) return undefined;
  const name = conferenceName(id, league);
  return name === "Other" ? undefined : name;
}

/**
 * A record worth printing.
 *
 * "0-0" is hidden — the preseason gate the app already applies to a team's
 * standing line. A team that hasn't played says nothing about its season
 * rather than claiming a blank one.
 */
function playedRecord(record: string | undefined): string | undefined {
  if (!record) return undefined;
  const trimmed = record.trim();
  if (!trimmed || /^0-0(-0)?$/.test(trimmed)) return undefined;
  return trimmed;
}

/**
 * The description an unfurl prints under the title.
 *
 * Deliberately carries **no numbers**. Slack and X cache an unfurl, so
 * every figure in one freezes at whatever it was when the first person
 * pasted the link — which is a trap the backlog named for the game card
 * and accepted there, because a matchup card with no score is not a
 * matchup card. A team's description has no such excuse: the record is on
 * the image, where it reads as a snapshot, and the sentence underneath
 * stays true all season.
 */
function describeTeam(school: string): string {
  return `Every ${school} game: schedule, live scores and standings.`;
}

export function teamCardModel(
  league: League,
  schedule: TeamScheduleData
): EntityCardModel {
  const team = schedule.team;
  const school = team?.school?.trim() || "Team";
  const conference = namedConference(team?.conferenceId, league);
  // The current season's record — an image route takes no `?year=`, so
  // there is no past season to be looking at here.
  const record = playedRecord(schedule.record ?? schedule.derivedRecord);
  const subtitle = [conference, record].filter(Boolean).join(" · ");

  return {
    kicker: displayName(league).toUpperCase(),
    title: school,
    subtitle: subtitle || undefined,
    logoUrl: team?.logoUrl,
    alt: `${school} on StatSide`,
    description: describeTeam(school),
  };
}

/**
 * The conference's own hero: its mark, its name, and how many teams are in
 * it — summed across divisions however the tables are sliced, exactly as
 * `ConferenceView` counts them.
 */
export function conferenceCardModel(
  league: League,
  name: string,
  logoUrl: string | undefined,
  tables: readonly ConferenceStandingsGroup[] | null
): EntityCardModel {
  const teamCount = (tables ?? []).reduce(
    (total, table) => total + table.entries.length,
    0
  );
  // "NFL" over "NFL" over the NFL shield says one thing three times.
  const kicker = displayName(league).toUpperCase();
  return {
    kicker: kicker === name.toUpperCase() ? undefined : kicker,
    title: name,
    subtitle: teamCount > 0 ? `${teamCount} teams` : undefined,
    logoUrl,
    alt: `${name} on StatSide`,
    description: `Every ${name} game: standings, schedule and live scores.`,
  };
}
