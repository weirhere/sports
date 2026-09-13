// What these two teams have done to each other before — the web twin of
// iOS `HeadToHead` (StatSideShared/Models/HeadToHead.swift).
//
// **The tally is of the window, and the window is not history.** ESPN
// publishes no head-to-head resource, so a series is assembled by walking one
// team's schedules back season by season (see `headToHead` in the provider) —
// which means the record here is "since 2017", never "all-time". Alabama and
// Tennessee have met 100+ times; printing "Alabama leads 7-3" without saying
// what it counts would be a flat lie, so `windowLabel` travels with the
// numbers and every surface renders it.
//
// Pure: the filter, the tally and the sentence are all derivable from the
// games, so the rules for what counts are testable without a network.

import type { Game, GameTeam, Team } from "@/lib/types";
import { seasonLabel, type League } from "@/lib/leagues";

export interface HeadToHead {
  /**
   * The meetings, newest first. Finals only — a scheduled rematch is not
   * history, and neither is the game this was built for.
   */
  meetings: Game[];
  /**
   * Wins for the side that is away in the game this was built for. Which end
   * they played from in any given meeting is beside the point: the tally
   * follows the team, not the fixture.
   */
  awayWins: number;
  homeWins: number;
  /**
   * College football could still tie until 1996 and hockey until 2005. Inside
   * any window we fetch it should always be zero — but a series that quietly
   * dropped a game rather than admit it was drawn would be the one bug nobody
   * would ever see.
   */
  ties: number;
  /** The earliest season searched — the window's floor, not the first meeting. */
  earliestSeason: number;
  league: League;
}

export type LeadingSide = "away" | "home";

export function seriesIsEmpty(series: HeadToHead): boolean {
  return series.meetings.length === 0;
}

/**
 * "Since 2017", "Since 2024-25" — the caption that keeps the tally honest
 * about what it counted.
 */
export function windowLabel(series: HeadToHead): string {
  return `Since ${seasonLabel(series.league, series.earliestSeason)}`;
}

/**
 * Which side is ahead, for the weight the numbers wear. Undefined when the
 * series is level, so neither number takes the emphasis.
 */
export function leadingSide(series: HeadToHead): LeadingSide | undefined {
  if (series.awayWins > series.homeWins) return "away";
  if (series.homeWins > series.awayWins) return "home";
  return undefined;
}

/**
 * The series in a sentence, for screen readers and anywhere a line of prose
 * beats a scoreboard: "Georgia leads 6-4 since 2017".
 */
export function seriesSentence(
  series: HeadToHead,
  away: Team,
  home: Team
): string {
  const window = windowLabel(series).toLowerCase();
  if (seriesIsEmpty(series)) return `No meetings ${window}`;
  const tie = series.ties > 0 ? `-${series.ties}` : "";
  switch (leadingSide(series)) {
    case "away":
      return `${away.school} leads ${series.awayWins}-${series.homeWins}${tie} ${window}`;
    case "home":
      return `${home.school} leads ${series.homeWins}-${series.awayWins}${tie} ${window}`;
    default:
      return `Series level at ${series.awayWins}-${series.homeWins}${tie} ${window}`;
  }
}

function kickoff(game: Game): number {
  const parsed = Date.parse(game.scheduledAt);
  return Number.isNaN(parsed) ? Number.NaN : parsed;
}

/**
 * True when the anchor's away team won this meeting, false when the home team
 * did, undefined for a draw.
 *
 * Scores first, ESPN's winner flag second: the flag is missing often enough on
 * older payloads that trusting it alone loses games, and two numbers can't
 * disagree with themselves. A meeting with neither is a tie by arithmetic,
 * which is wrong — so it takes the flag's answer when there is one and is only
 * counted level when nothing says otherwise.
 */
function awayWon(meeting: Game, awayId: string): boolean | undefined {
  const isAway = meeting.awayTeam.team.id === awayId;
  const mine: GameTeam = isAway ? meeting.awayTeam : meeting.homeTeam;
  const theirs: GameTeam = isAway ? meeting.homeTeam : meeting.awayTeam;
  if (mine.score !== null && theirs.score !== null && mine.score !== theirs.score) {
    return mine.score > theirs.score;
  }
  if (mine.isWinner === true) return true;
  if (theirs.isWinner === true) return false;
  return undefined;
}

/**
 * Builds the series from one team's fetched seasons.
 *
 * `games` is everything that team played across the window — the filter to the
 * matchup lives here rather than at the fetch so it is testable without a
 * network, and so the rules for what counts are written down in one place:
 *
 * - **Both these teams**, by id. Ids collide across leagues, never inside one,
 *   and a window is always fetched inside one league.
 * - **Final only.** A postponed game was never played and a scheduled rematch
 *   has not been.
 * - **Not this game**, by id — and not anything after it. Open a 2019 game and
 *   the series is what it was in 2019; the meetings since are not history the
 *   2019 page can have known about.
 * - **Exhibitions excluded** upstream, by the fetch. A preseason game has never
 *   counted in a head-to-head record and it does not start here.
 */
export function makeHeadToHead(
  games: Game[],
  anchor: Game,
  earliestSeason: number
): HeadToHead {
  const awayId = anchor.awayTeam.team.id;
  const homeId = anchor.homeTeam.team.id;
  const anchorDate = kickoff(anchor);
  const seen = new Set<string>();

  const meetings = games
    .filter((game) => {
      if (game.id === anchor.id || seen.has(game.id)) return false;
      if (game.status !== "complete") return false;
      const ids = [game.awayTeam.team.id, game.homeTeam.team.id];
      if (!ids.includes(awayId) || !ids.includes(homeId)) return false;
      seen.add(game.id);
      // Before this one. A game with no date can't be placed against the
      // anchor, so it is kept rather than guessed at.
      const date = kickoff(game);
      if (Number.isNaN(anchorDate) || Number.isNaN(date)) return true;
      return date < anchorDate;
    })
    // Newest first: the last meeting is the one anybody asks about. Undated
    // meetings sort last rather than jumping the queue.
    .sort((a, b) => {
      const at = kickoff(a);
      const bt = kickoff(b);
      return (
        (Number.isNaN(bt) ? -Infinity : bt) - (Number.isNaN(at) ? -Infinity : at)
      );
    });

  let awayWins = 0;
  let homeWins = 0;
  let ties = 0;
  for (const meeting of meetings) {
    const won = awayWon(meeting, awayId);
    if (won === true) awayWins += 1;
    else if (won === false) homeWins += 1;
    else ties += 1;
  }

  return {
    meetings,
    awayWins,
    homeWins,
    ties,
    earliestSeason,
    league: anchor.league,
  };
}
