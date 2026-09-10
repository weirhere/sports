// The league axis — a port of the iOS app's `League`, `SeasonYear` and
// `SeasonSpan` (StatSideShared/Models/League.swift, SeasonYear.swift).
//
// Every ESPN request, every id namespace and every time-model rule hangs off
// this. ESPN's team and conference id spaces are per-league and they collide
// hard: 20 of 32 NFL team ids are also real college teams (UCLA/Seahawks,
// Stanford/Chargers, USC/Jaguars), and group id 8 is the SEC in college
// football and the AFC in the NFL.

/**
 * The raw value is the persistence token. It is written into follow keys,
 * filter tokens and URLs, so it must never change.
 */
export const LEAGUES = ["cfb", "nfl", "nba", "nhl"] as const;

export type League = (typeof LEAGUES)[number];

export function isLeague(value: string | null | undefined): value is League {
  return value != null && (LEAGUES as readonly string[]).includes(value);
}

/** Parses a URL segment or stored token, or `undefined` if it isn't one. */
export function parseLeague(value: string | null | undefined): League | undefined {
  return isLeague(value) ? value : undefined;
}

interface LeagueSpec {
  /**
   * The sport path segment above the league's own. Football's two leagues
   * share it; basketball and hockey do not.
   */
  sportSegment: string;
  /**
   * The league path segment under the sport. Verified live 2026-09-08:
   * scoreboard, standings, summary and team-schedule responses are
   * shape-identical across all four.
   */
  pathSegment: string;
  /** Row- and chip-width name. */
  shortName: string;
  displayName: string;
  /** The calendar month a season's first game can fall in. */
  seasonOpensIn: number;
  /** The last calendar month that still belongs to the *previous* season. */
  seasonRollsOverAfter: number;
  /** Whether ESPN stamps a season with the calendar year it *ends* in. */
  seasonYearIsEndYear: boolean;
  /** Regulation period count and the names a status line uses. */
  periodFormat: { regulationCount: number; longName: string; shortName: string };
  /** What the Scoring slot is called, or null where it would be noise. */
  scoringCardTitle: string | null;
  /** What a game starting is called. */
  startNoun: string;
  startVerbPhrase: string;
  /** The Leaders card's preferred categories, in display order. */
  leaderCategories: { name: string; label: string }[];
  /** The team stats the compare card lines up, in order. ESPN's own names. */
  comparedStats: { name: string; label: string }[];
}

const SPECS: Record<League, LeagueSpec> = {
  cfb: {
    sportSegment: "football",
    pathSegment: "college-football",
    shortName: "CFB",
    displayName: "College Football",
    // Week 0's last weekend.
    seasonOpensIn: 8,
    // Bowls and the CFP run into January.
    seasonRollsOverAfter: 1,
    seasonYearIsEndYear: false,
    periodFormat: { regulationCount: 4, longName: "QUARTER", shortName: "Q" },
    scoringCardTitle: "Scoring",
    startNoun: "Kickoff",
    startVerbPhrase: "kicks off",
    leaderCategories: [
      { name: "passingYards", label: "Passing" },
      { name: "rushingYards", label: "Rushing" },
      { name: "receivingYards", label: "Receiving" },
    ],
    comparedStats: [
      { name: "totalYards", label: "Total Yards" },
      { name: "netPassingYards", label: "Passing" },
      { name: "rushingYards", label: "Rushing" },
      { name: "thirdDownEff", label: "3rd Down" },
      { name: "turnovers", label: "Turnovers" },
      { name: "possessionTime", label: "Possession" },
    ],
  },
  nfl: {
    sportSegment: "football",
    pathSegment: "nfl",
    shortName: "NFL",
    displayName: "NFL",
    // The Hall of Fame Game is in late July; an August floor cut the front
    // off the season entirely (Andy, 2026-09-06).
    seasonOpensIn: 7,
    // The Super Bowl is in February.
    seasonRollsOverAfter: 2,
    seasonYearIsEndYear: false,
    periodFormat: { regulationCount: 4, longName: "QUARTER", shortName: "Q" },
    scoringCardTitle: "Scoring",
    startNoun: "Kickoff",
    startVerbPhrase: "kicks off",
    leaderCategories: [
      { name: "passingYards", label: "Passing" },
      { name: "rushingYards", label: "Rushing" },
      { name: "receivingYards", label: "Receiving" },
    ],
    comparedStats: [
      { name: "totalYards", label: "Total Yards" },
      { name: "netPassingYards", label: "Passing" },
      { name: "rushingYards", label: "Rushing" },
      { name: "thirdDownEff", label: "3rd Down" },
      { name: "turnovers", label: "Turnovers" },
      { name: "possessionTime", label: "Possession" },
    ],
  },
  nba: {
    sportSegment: "basketball",
    pathSegment: "nba",
    shortName: "NBA",
    displayName: "NBA",
    // ESPN's own season object starts 2026-09-30 (probed 2026-09-08).
    seasonOpensIn: 9,
    // The Finals are decided in June.
    seasonRollsOverAfter: 6,
    seasonYearIsEndYear: true,
    periodFormat: { regulationCount: 4, longName: "QUARTER", shortName: "Q" },
    // Basketball scores ~98 times a game: a chronological list of every
    // bucket is the box score with worse formatting.
    scoringCardTitle: null,
    startNoun: "Tip-off",
    startVerbPhrase: "tips off",
    leaderCategories: [
      { name: "points", label: "Points" },
      { name: "rebounds", label: "Rebounds" },
      { name: "assists", label: "Assists" },
    ],
    comparedStats: [
      { name: "fieldGoalPct", label: "FG%" },
      { name: "threePointFieldGoalPct", label: "3PT%" },
      { name: "totalRebounds", label: "Rebounds" },
      { name: "assists", label: "Assists" },
      { name: "turnovers", label: "Turnovers" },
    ],
  },
  nhl: {
    sportSegment: "hockey",
    pathSegment: "nhl",
    shortName: "NHL",
    displayName: "NHL",
    // ESPN's own season object starts 2025-09-20 (probed 2026-09-08).
    seasonOpensIn: 9,
    // The Stanley Cup is decided in June.
    seasonRollsOverAfter: 6,
    seasonYearIsEndYear: true,
    periodFormat: { regulationCount: 3, longName: "PERIOD", shortName: "P" },
    // Hockey's goals are the same shape as football's scoring plays, and
    // ESPN flags them on the play feed.
    scoringCardTitle: "Goals",
    startNoun: "Puck drop",
    startVerbPhrase: "drops the puck",
    leaderCategories: [
      { name: "goals", label: "Goals" },
      { name: "assists", label: "Assists" },
      { name: "points", label: "Points" },
    ],
    comparedStats: [
      { name: "shotsTotal", label: "Shots" },
      { name: "powerPlayGoals", label: "Power Play" },
      { name: "faceoffPercent", label: "Faceoffs" },
      { name: "hits", label: "Hits" },
      { name: "penaltyMinutes", label: "Penalty Min" },
    ],
  },
};

export function leagueSpec(league: League): LeagueSpec {
  return SPECS[league];
}

/**
 * What a league calls its scoring periods — four quarters in football and
 * basketball, three periods in hockey.
 */
export function periodFormat(league: League): {
  regulationCount: number;
  longName: string;
  shortName: string;
} {
  return league === "nhl"
    ? { regulationCount: 3, longName: "PERIOD", shortName: "P" }
    : { regulationCount: 4, longName: "QUARTER", shortName: "Q" };
}

/**
 * What the Summary tab calls its derived-scoring card, where it has one.
 *
 * Basketball gets none: ~98 buckets a game is the box score with worse
 * formatting. Hockey's is "Goals" — and ESPN ships no `scoringPlays` for it,
 * so the card is derived off the play feed instead.
 */
export function scoringCardTitle(league: League): string | undefined {
  switch (league) {
    case "cfb":
    case "nfl":
      return "Scoring";
    case "nhl":
      return "Goals";
    case "nba":
      return undefined;
  }
}

/** ESPN's site API base for one league. */
export function apiBase(league: League): string {
  const { sportSegment, pathSegment } = SPECS[league];
  return `https://site.api.espn.com/apis/site/v2/sports/${sportSegment}/${pathSegment}`;
}

/**
 * The league's own path under ESPN's sport hierarchy — "football/nfl",
 * "basketball/nba". Every base URL is this plus a host.
 */
export function leaguePath(league: League): string {
  const { sportSegment, pathSegment } = SPECS[league];
  return `${sportSegment}/leagues/${pathSegment}`;
}

/**
 * The standings API base — `apis/v2`, not `site/v2`. Conference membership
 * lives here; the `/teams` endpoint carries no conference data.
 */
export function standingsApiBase(league: League): string {
  const { sportSegment, pathSegment } = SPECS[league];
  return `https://site.api.espn.com/apis/v2/sports/${sportSegment}/${pathSegment}`;
}

export function shortName(league: League): string {
  return SPECS[league].shortName;
}

export function displayName(league: League): string {
  return SPECS[league].displayName;
}

/**
 * The league's own mark — the one ESPN's own scoreboard declares for it in
 * `leagues[].logos[]`.
 *
 * Three of the four sit in the `leagues/` bucket beside the team marks;
 * college football's does not (`college-football`, `ncaa`, `ncaaf`, `cfb`
 * and `ncaa_football` all 404 there). ESPN files it under `redesign/`
 * instead and ships it on every NCAAF scoreboard response.
 *
 * None derives a dark twin: a header badge rides a light backing disc in
 * dark mode, where a light-inked shield would vanish.
 */
export function leagueLogoUrl(league: League): string {
  if (league === "cfb") {
    return "https://a.espncdn.com/redesign/assets/img/icons/ESPN-icon-football-college.png";
  }
  return `https://a.espncdn.com/i/teamlogos/leagues/500/${SPECS[league].pathSegment}.png`;
}

/** The team-logo CDN bucket for this league. */
export function teamLogoBase(league: League): string {
  return league === "cfb"
    ? "https://a.espncdn.com/i/teamlogos/ncaa/500"
    : `https://a.espncdn.com/i/teamlogos/${SPECS[league].pathSegment}/500`;
}

/** The conference-mark CDN bucket for this league. */
export function conferenceLogoBase(league: League): string {
  return league === "cfb"
    ? "https://a.espncdn.com/i/teamlogos/ncaa_conf/500"
    : `https://a.espncdn.com/i/teamlogos/${SPECS[league].pathSegment}/500`;
}

// --- Season-year translation -------------------------------------------
//
// Football names a season by the year it opens: the 2026 season is August
// 2026 through February 2027. The NBA and NHL do the opposite —
// `season=2027` is October 2026 through June 2027, `displayName` "2026-27"
// (probed live 2026-09-08).
//
// Our own axis is always the opening year, everywhere. The translation
// happens at exactly one boundary — the query string — which is the same
// rule that keeps ESPN's shapes out of the rest of the app.

/** Our opening-year season → the value ESPN's `season=`/`dates=` wants. */
export function espnSeason(league: League, year: number): number {
  return SPECS[league].seasonYearIsEndYear ? year + 1 : year;
}

/** The inverse, for reading a payload's `season.year` back onto our axis. */
export function seasonYearFromEspn(league: League, year: number): number {
  return SPECS[league].seasonYearIsEndYear ? year - 1 : year;
}

/**
 * "2026" for football, "2026-27" for the NBA and NHL — ESPN's own
 * `displayName` spelling. The two-digit pad matters at the decade boundary:
 * 2009 is "2009-10", never "2009-1".
 */
export function seasonLabel(league: League, year: number): string {
  if (!SPECS[league].seasonYearIsEndYear) return String(year);
  return `${year}-${String((year + 1) % 100).padStart(2, "0")}`;
}

/** How far back the season picker goes — the CFP era, for every league. */
export const SEASON_FLOOR = 2014;

// --- Behavioral gates ---------------------------------------------------

/**
 * Whether the day's slate breaks into one section per conference, or stands
 * as one section for the league.
 *
 * Only college football is wide enough to need carving — 60 rows on a
 * Saturday with no way in, and conferences are how fans already carve one up
 * (Andy, 2026-09-06). A 16-game NFL Sunday, an 11-game NBA night and an
 * 8-game NHL night are each the whole slate at a glance.
 */
export function slateSplitsByConference(league: League): boolean {
  return league === "cfb";
}

/**
 * Whether the season has weeks worth grouping by. ESPN sends `week: null` on
 * every NBA and NHL event and ships an empty `leagues[].calendar` for both
 * (probed 2026-09-08), so a Weeks toggle there files a whole season under
 * one unnamed card.
 */
export function hasWeeks(league: League): boolean {
  return !SPECS[league].seasonYearIsEndYear;
}

/**
 * Whether this league's scoreboard and standings take college football's
 * FBS/FCS `groups=` parameter.
 */
export function hasCollegeDivisions(league: League): boolean {
  return league === "cfb";
}

/**
 * Whether the league ranks its teams. College football has the AP, Coaches
 * and CFP polls; `/rankings` is a 404 for the other three and always will be
 * (probed 2026-09-08).
 */
export function hasPoll(league: League): boolean {
  return league === "cfb";
}

/**
 * Whether a conference or league page can afford to table its whole season
 * on a Games tab.
 *
 * College football's season is ~950 events, which one `dates=` window
 * carries. The NBA's is ~1,300 and it does not: probed live 2026-09-08,
 * `dates=20251001-20260630&limit=900` returns exactly 900 events and 12 MB,
 * silently truncating at February 20 — and adding `groups=5` returns the
 * identical 900, because ESPN ignores the group filter outside football, so
 * there is no narrow fetch to fall back on either.
 */
export function canTableAWholeSeason(league: League): boolean {
  return !SPECS[league].seasonYearIsEndYear;
}

/**
 * How many days either side of today a Games tab reaches for a league whose
 * whole season it cannot fetch: a week back and three weeks forward, in one
 * request of about a megabyte.
 */
export const GAMES_WINDOW = { back: 7, forward: 21 } as const;

/**
 * Whether the surface underfoot is a fact about the game.
 *
 * Football is played on grass or turf and which one is a real difference.
 * Basketball and hockey are played indoors — ESPN still ships
 * `grass: false` for their arenas, which read as "Surface · Turf" on a
 * hockey rink (Andy, 2026-09-09).
 */
export function playsOnASurface(league: League): boolean {
  return !SPECS[league].seasonYearIsEndYear;
}

// --- Season timing ------------------------------------------------------

/**
 * The season a date belongs to, per league. Months up to and including the
 * league's rollover month belong to the *previous* season.
 */
export function seasonYear(league: League, now: Date = new Date()): number {
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  return month <= SPECS[league].seasonRollsOverAfter ? year - 1 : year;
}

/** Selectable seasons for one league, newest first, down to the floor. */
export function seasonYears(league: League, now: Date = new Date()): number[] {
  const current = seasonYear(league, now);
  const years: number[] = [];
  for (let year = current; year >= SEASON_FLOOR; year -= 1) years.push(year);
  return years;
}

/**
 * The calendar a season occupies — the Scores screen's day-strip bounds.
 *
 * Derived rather than fetched. ESPN publishes a season calendar on the plain
 * scoreboard request, but a `dates=` request — the only one the day axis
 * makes — returns none at all, and no calendar exists for a past season
 * anyway (verified live 2026-09-05). A season's span is a rule, not a
 * lookup: it opens when the league's first game can, and closes when the
 * league's rollover month does.
 *
 * Returned as local dates at midnight, inclusive of both ends.
 */
export function seasonSpan(
  league: League,
  year: number
): { start: Date; end: Date } {
  const spec = SPECS[league];
  const start = new Date(year, spec.seasonOpensIn - 1, 1);
  // The first of the month after the rollover month, minus a day — so
  // February's length is never spelled out and leap years are free.
  const end = new Date(year + 1, spec.seasonRollsOverAfter, 0);
  return { start, end: end < start ? start : end };
}

/**
 * Every covered league's season at once. College football's August opens the
 * app's season; the NBA's and NHL's June closes it — which is why the app no
 * longer has an offseason.
 */
export function unionSeasonSpan(year: number): { start: Date; end: Date } {
  const spans = LEAGUES.map((league) => seasonSpan(league, year));
  const start = new Date(Math.min(...spans.map((s) => s.start.getTime())));
  const end = new Date(Math.max(...spans.map((s) => s.end.getTime())));
  return { start, end: end < start ? start : end };
}

/**
 * The season a given day belongs to, by the same rollover rule. A day in the
 * rollover months belongs to the season that opened the previous summer, and
 * the app's season runs until the last league's does.
 */
export function seasonYearContaining(day: Date): number {
  const latest = Math.max(...LEAGUES.map((l) => SPECS[l].seasonRollsOverAfter));
  const month = day.getMonth() + 1;
  return month <= latest ? day.getFullYear() - 1 : day.getFullYear();
}
