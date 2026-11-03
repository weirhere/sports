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
export const LEAGUES = ["cfb", "nfl", "nba", "nhl", "mcbb", "wcbb"] as const;

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
  /** The sport, which every "is this football?" gate reads (iOS `League.sport`). */
  sport: Sport;
  /** A college league: conferences of schools, polls, class years. */
  isCollege: boolean;
  /**
   * The `groups=` the scoreboard and standings are scoped to — FBS (80) in
   * college football, Division I (50) in college basketball — or null for
   * the pros, whose slate is the whole league.
   */
  divisionGroupId: number | null;
}

export type Sport = "football" | "basketball" | "hockey";

const BASKETBALL_LEADERS = [
  { name: "points", label: "Points" },
  { name: "rebounds", label: "Rebounds" },
  { name: "assists", label: "Assists" },
];

const BASKETBALL_COMPARED = [
  { name: "fieldGoalPct", label: "FG%" },
  { name: "threePointFieldGoalPct", label: "3PT%" },
  { name: "totalRebounds", label: "Rebounds" },
  { name: "assists", label: "Assists" },
  { name: "turnovers", label: "Turnovers" },
];

const SPECS: Record<League, LeagueSpec> = {
  cfb: {
    sportSegment: "football",
    pathSegment: "college-football",
    shortName: "NCAAF",
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
    sport: "football",
    isCollege: true,
    divisionGroupId: 80,
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
    sport: "football",
    isCollege: false,
    divisionGroupId: null,
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
    leaderCategories: BASKETBALL_LEADERS,
    comparedStats: BASKETBALL_COMPARED,
    sport: "basketball",
    isCollege: false,
    divisionGroupId: null,
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
    sport: "hockey",
    isCollege: false,
    divisionGroupId: null,
  },
  // College basketball (2026-11-02, iOS's same day). "NCAAM" and "NCAAW"
  // for the reason "NCAAF" is: ESPN's and the broadcasts' word. Both are
  // end-year, weekless, D-I-scoped (`groups=50`) leagues, probed live.
  mcbb: {
    sportSegment: "basketball",
    pathSegment: "mens-college-basketball",
    shortName: "NCAAM",
    displayName: "Men's College Basketball",
    // Exhibitions in late October; the season opens the first Monday of
    // November.
    seasonOpensIn: 10,
    // The Final Four is the first weekend of April.
    seasonRollsOverAfter: 4,
    seasonYearIsEndYear: true,
    // Two 20-minute halves; period 3 is the first overtime.
    periodFormat: { regulationCount: 2, longName: "HALF", shortName: "H" },
    scoringCardTitle: null,
    startNoun: "Tip-off",
    startVerbPhrase: "tips off",
    leaderCategories: BASKETBALL_LEADERS,
    comparedStats: BASKETBALL_COMPARED,
    sport: "basketball",
    isCollege: true,
    divisionGroupId: 50,
  },
  wcbb: {
    sportSegment: "basketball",
    pathSegment: "womens-college-basketball",
    shortName: "NCAAW",
    displayName: "Women's College Basketball",
    seasonOpensIn: 10,
    seasonRollsOverAfter: 4,
    seasonYearIsEndYear: true,
    // Four 10-minute quarters, unlike the men.
    periodFormat: { regulationCount: 4, longName: "QUARTER", shortName: "Q" },
    scoringCardTitle: null,
    startNoun: "Tip-off",
    startVerbPhrase: "tips off",
    leaderCategories: BASKETBALL_LEADERS,
    comparedStats: BASKETBALL_COMPARED,
    sport: "basketball",
    isCollege: true,
    divisionGroupId: 50,
  },
};

export function leagueSpec(league: League): LeagueSpec {
  return SPECS[league];
}

/** The sport a league plays. */
export function sportOf(league: League): Sport {
  return SPECS[league].sport;
}

export function isFootball(league: League): boolean {
  return SPECS[league].sport === "football";
}

export function isBasketball(league: League): boolean {
  return SPECS[league].sport === "basketball";
}

/**
 * Whether this is a college league — college football and both college
 * basketballs. Until 2026-11-02 this was spelled `league === "cfb"`, which
 * meant "college", "football" or "FBS/FCS" depending on the site; each site
 * now asks the question it means.
 */
export function isCollege(league: League): boolean {
  return SPECS[league].isCollege;
}

/** College basketball, men's or women's. */
export function isCollegeBasketball(league: League): boolean {
  return isCollege(league) && isBasketball(league);
}

/**
 * The college league a pro's College row opens (iOS `League.collegeFeeder`,
 * 2026-11-02): an NBA player's school opens its men's basketball page; an
 * NFL's, and an NHL's as before, its football page. Undefined for a
 * college league.
 */
export function collegeFeeder(league: League): League | undefined {
  switch (league) {
    case "nfl":
    case "nhl":
      return "cfb";
    case "nba":
      return "mcbb";
    case "cfb":
    case "mcbb":
    case "wcbb":
      return undefined;
  }
}

/** The scoreboard's and standings' `groups=` — FBS (80), Division I (50) —
 * or undefined for the pros (iOS `League.divisionGroupId`). */
export function leagueGroupId(league: League): number | undefined {
  return SPECS[league].divisionGroupId ?? undefined;
}

/**
 * What a league calls its scoring periods — four quarters in football, the
 * NBA and women's college basketball, two halves in men's college
 * basketball, three periods in hockey.
 */
export function periodFormat(league: League): {
  regulationCount: number;
  longName: string;
  shortName: string;
} {
  return SPECS[league].periodFormat;
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
    case "mcbb":
    case "wcbb":
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

/**
 * The order leagues are *shown* in: A–Z by the name on screen — NBA, NCAAF,
 * NFL, NHL (iOS `League.displayOrder`, 2026-09-24). With four leagues on one
 * page and the season running July to June, alphabetical is the order a
 * reader recognises without being told; football-first only ever held
 * because it came first. The Scores stack, the Leagues hub and a new
 * follow's default position all read this.
 *
 * Declared below `SPECS`, which `shortName` reads. Deliberately a copy, not
 * a re-sort of `LEAGUES`: that array's order is the declaration's, and fetch
 * fan-outs and season spans iterate it.
 */
export const LEAGUE_DISPLAY_ORDER: readonly League[] = [...LEAGUES].sort(
  (lhs, rhs) => (shortName(lhs) < shortName(rhs) ? -1 : 1)
);

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
  // Declared on each league's own scoreboard, `leagues[].logos[]`
  // (probed 2026-11-02).
  if (league === "mcbb") {
    return "https://a.espncdn.com/redesign/assets/img/icons/NCAASports_MensBasketball.png";
  }
  if (league === "wcbb") {
    return "https://a.espncdn.com/redesign/assets/img/icons/NCAASports_WomensBasketball.png";
  }
  return `https://a.espncdn.com/i/teamlogos/leagues/500/${SPECS[league].pathSegment}.png`;
}

/** The team-logo CDN bucket for this league. */
export function teamLogoBase(league: League): string {
  // One NCAA bucket for every college sport: the team ids are shared.
  return isCollege(league)
    ? "https://a.espncdn.com/i/teamlogos/ncaa/500"
    : `https://a.espncdn.com/i/teamlogos/${SPECS[league].pathSegment}/500`;
}

/** The conference-mark CDN bucket for this league. */
export function conferenceLogoBase(league: League): string {
  return isCollege(league)
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
  // College basketball too (2026-11-02): ~180 Division I games a night.
  return isCollege(league);
}

/**
 * Whether the season has weeks worth grouping by. ESPN sends `week: null` on
 * every NBA and NHL event and ships an empty `leagues[].calendar` for both
 * (probed 2026-09-08), so a Weeks toggle there files a whole season under
 * one unnamed card.
 */
export function hasWeeks(league: League): boolean {
  // Football's alone (2026-11-03): was `!seasonYearIsEndYear`, which stops
  // holding once a calendar-year league (MLB, the WNBA) arrives.
  return isFootball(league);
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
  // College basketball's AP and Coaches polls too (probed 2026-11-02).
  return isCollege(league);
}

/** Whether the league has a College Football Playoff ranking (core id 21). */
export function hasPlayoffRanking(league: League): boolean {
  return league === "cfb";
}

/**
 * How many seasons back a head-to-head series is assembled from.
 *
 * The window is really sized in *meetings* — ten is the list length that
 * answers "who usually wins this" without becoming a scroll — and expressed
 * in seasons, because seasons are what can be fetched. So the number follows
 * how often two teams meet: football's leagues play each other once or twice
 * a year, basketball's and hockey's two to four times.
 *
 * It is also the request bill. ESPN publishes no head-to-head resource, so a
 * series costs two requests per season (the regular season and the
 * postseason, which is where the rivalry games worth remembering are) — 20
 * for college football, 12 for the NFL, 6 for the others. Paid once, on an
 * explicit tap, and never polled; this constant is the dial if that is ever
 * too much.
 */
export function headToHeadSeasons(league: League): number {
  switch (league) {
    case "cfb":
      return 10; // one meeting a year, so ten of them
    case "nfl":
      return 6; // twice a year inside a division
    case "nba":
    case "nhl":
    case "mcbb":
    case "wcbb":
      return 3; // two to four times a year
  }
}

/**
 * Whether the surface underfoot is a fact about the game.
 *
 * Football is played on grass or turf and which one is a real difference.
 * Basketball and hockey are played indoors — ESPN still ships
 * `grass: false` for their arenas, which read as "Surface · Turf" on a
 * hockey rink (Andy, 2026-09-09).
 */
export function playsOnASurface(league: League): boolean {
  return isFootball(league);
}

/**
 * Whether a season crosses New Year — August to January, October to June.
 * MLB and the WNBA run inside one calendar year, and the season rules below
 * branch on it (iOS `League.seasonSpansNewYear`, 2026-11-03).
 */
export function seasonSpansNewYear(league: League): boolean {
  const spec = SPECS[league];
  return spec.seasonRollsOverAfter < spec.seasonOpensIn;
}

/** The leagues whose seasons cross New Year — the ones the app's July–June
 *  season is computed over. A calendar-year league's games fall on days
 *  inside one app season or the next. */
function spanningLeagues(): League[] {
  return LEAGUES.filter(seasonSpansNewYear);
}

// --- Season timing ------------------------------------------------------

/**
 * The season a date belongs to, per league. Months up to and including the
 * league's rollover month belong to the *previous* season.
 */
export function seasonYear(league: League, now: Date = new Date()): number {
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  // A calendar-year league is in its new season from its opening month; the
  // winter before it still shows the season just played.
  if (!seasonSpansNewYear(league)) {
    return month < SPECS[league].seasonOpensIn ? year - 1 : year;
  }
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
  // A calendar-year league closes in the year it opened.
  const end = new Date(
    seasonSpansNewYear(league) ? year + 1 : year,
    spec.seasonRollsOverAfter,
    0
  );
  return { start, end: end < start ? start : end };
}

/**
 * The seasons that did not end when the rule says they do — the month each
 * one's last game was actually played in, of the calendar year after the
 * season's own.
 *
 * Swept live 2026-09-25 across every season the picker reaches (2014 on):
 * July and August are empty in both leagues every year except these, and
 * September belongs to the *new* season every year except 2020. Both are
 * the pandemic — the 2019-20 bubbles finished in the autumn (the NBA Finals
 * on October 11, the Stanley Cup on September 28), and the 2020-21 seasons
 * that started late ran into July (the 20th and the 7th).
 */
const SEASON_OVERRUNS: Partial<Record<League, Record<number, number>>> = {
  nba: { 2019: 10, 2020: 7 },
  nhl: { 2019: 9, 2020: 7 },
};

/**
 * The calendar a season's **games** occupy — `seasonSpan` widened where a
 * season ran past its league's rollover month, for a Games tab that tables
 * the season whole.
 *
 * Deliberately a second span rather than a change to the first: the day
 * strip's bounds and `seasonYearContaining` are rules about which season a
 * *day* belongs to, and a day in August 2020 has two answers. The spans
 * overlap for exactly those seasons, so a fetch over this one must also keep
 * only the events ESPN stamps with its season — see `belongsToSeason`.
 */
export function seasonGamesSpan(
  league: League,
  year: number
): { start: Date; end: Date } {
  const span = seasonSpan(league, year);
  const closesIn = SEASON_OVERRUNS[league]?.[year];
  if (closesIn === undefined) return span;
  // Day 0 of the month after is the last day of the month the season closed.
  const end = new Date(year + 1, closesIn, 0);
  return { start: span.start, end: end > span.end ? end : span.end };
}

/**
 * Whether an event ESPN stamped with `espnYear` belongs to our season
 * `year`. An event with no stamp is kept: a missing field degrades the
 * slate's edges, never empties it.
 */
export function belongsToSeason(
  league: League,
  year: number,
  espnYear: number | undefined
): boolean {
  return espnYear === undefined || seasonYearFromEspn(league, espnYear) === year;
}

/**
 * Every covered league's season at once. College football's August opens the
 * app's season; the NBA's and NHL's June closes it — which is why the app no
 * longer has an offseason.
 */
export function unionSeasonSpan(year: number): { start: Date; end: Date } {
  const spans = spanningLeagues().map((league) => seasonSpan(league, year));
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
  const latest = Math.max(...spanningLeagues().map((l) => SPECS[l].seasonRollsOverAfter));
  const month = day.getMonth() + 1;
  return month <= latest ? day.getFullYear() - 1 : day.getFullYear();
}
