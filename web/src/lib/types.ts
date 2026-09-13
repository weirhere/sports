// Core domain types for StatSide.
// All components import from here — never from raw API types.

import type { LivePhase } from "./format";
import type { League } from "./leagues";
import type { WeekSlot } from "./season";

export type GameStatus =
  | "scheduled"
  | "in_progress"
  | "halftime"
  | "end_period"
  | "complete"
  | "postponed"
  | "cancelled"
  | "delayed";

/**
 * College football's two divisions. Only ever meaningful for `league:
 * "cfb"` — the pro leagues have no counterpart, which is why this is
 * optional on a team rather than a required field with a fake default.
 */
export type Division = "FBS" | "FCS";

export interface Team {
  id: string;
  espnId: number;
  /**
   * Which league's id space `id` and `conferenceId` belong to.
   *
   * Not decoration: ESPN team ids collide across leagues (id 5 is UAB and
   * the Browns; id 2 is Auburn and the Bills), so nothing may key, route or
   * follow on `id` alone. Use `followKey({ league, teamId: id })`.
   */
  league: League;
  name: string; // e.g., "Crimson Tide"
  school: string; // e.g., "Alabama"
  abbreviation: string; // e.g., "ALA"
  conferenceId: string;
  conferenceName: string;
  /** College football only. */
  division?: Division;
  color?: string; // Primary brand color hex
  altColor?: string;
  logoUrl: string;
}

export interface GameTeam {
  team: Team;
  score: number | null;
  ranking?: number; // AP ranking if ranked
  record?: string; // e.g., "8-2"
  isWinner?: boolean;
  linescores?: number[]; // Quarter-by-quarter scores
}

export interface Venue {
  name: string;
  city: string;
  state: string;
}

export interface Game {
  id: string;
  /** Which league's event-id space `id` belongs to. A summary fetched from
   * the wrong league's base URL 404s, so this rides every game. */
  league: League;
  status: GameStatus;
  scheduledAt: string; // ISO 8601
  venue: Venue;
  homeTeam: GameTeam;
  awayTeam: GameTeam;
  broadcast?: string; // TV network
  clock?: string; // Game clock e.g., "3:42"
  quarter?: number; // Current quarter (1-4, 5=OT)
  possession?: "home" | "away";
  /** ESPN's week number, or `undefined` where the league has none — every
   * NBA and NHL event ships `week: null`. */
  week?: number;
  seasonYear: number;
  conferenceGame: boolean;
  /**
   * ESPN publishes a placeholder kickoff (midnight ET, `timeValid: false`)
   * until a game's time is announced. True means `scheduledAt`'s day is
   * real but its clock time is noise — render "TBD", never "12:00 AM".
   */
  timeTBD?: boolean;
  /**
   * ESPN's season type (2 regular, 3 postseason) when the payload says.
   * Week numbers restart in the postseason, so grouping a season's slate
   * by week needs this to keep a title game out of "Week 1".
   */
  seasonType?: number;
  /**
   * Where a live game's clock cycle stands. ESPN sends halftime and
   * end-of-quarter as `state: "in"` with the clock parked at 0:00 — set at
   * the transform boundary so renderers never re-derive it.
   */
  livePhase?: LivePhase;
  /** ESPN's status detail string — the degrade path for status lines. */
  statusDetail?: string;
  /**
   * ESPN's printed headline for the fixture. College football names its
   * playoff rounds here and nowhere else — its whole postseason is one
   * `seasontype=3` week, so "Quarterfinal at the Allstate Sugar Bowl" is
   * the only thing separating a quarterfinal from a bowl.
   */
  headline?: string;
}

export interface Conference {
  id: string;
  /** Which league's group-id space `id` belongs to — group 8 is the SEC
   * here and the AFC in the NFL. */
  league: League;
  name: string;
  shortName: string;
  /** College football only. */
  division?: Division;
  logoUrl?: string;
}

export interface ConferenceStanding {
  team: Team;
  conferenceWins: number;
  conferenceLosses: number;
  overallWins: number;
  overallLosses: number;
  conferenceRank: number;
  streakType?: "W" | "L";
  streakLength?: number;
  /** ESPN's record summary strings ("7-1") — display verbatim. */
  conferenceRecord?: string;
  overallRecord?: string;
  streak?: string;
  /**
   * ESPN's `playoffSeed` — the tiebreaker-aware standings position.
   * 1-based when ESPN knows it; absent (or ESPN's 0) when it doesn't.
   */
  playoffSeed?: number;
  /**
   * ESPN's `winpercent`, where the league keeps one — what a merged
   * league table ranks on. The NHL ships none.
   */
  winPercent?: number;
  /** Standings points, which is what the NHL ranks on instead. */
  points?: number;
  /** Games played — the NHL's leading column. */
  gamesPlayed?: number;
  /** ESPN's own "games back" string, "-" for the leader. */
  gamesBehind?: string;
  /** ESPN's own zero-stripped win percentage, ".732". */
  winPercentText?: string;
}

/**
 * A conference's standings in ESPN's order — which encodes tiebreakers and
 * is not derivable from the records. Empty `entries` are kept: offseason
 * responses can have zero entries and the page needs to say "Standings
 * TBA", not error.
 */
export interface ConferenceStandingsGroup {
  id: string;
  league: League;
  /**
   * Set when this table is a division hanging under a conference — the
   * 2019 AAC's East and West, or a pro league's `level=3` request. The page
   * for the parent conference collects these instead of finding nothing.
   */
  parentId?: number;
  /**
   * Set on a table merged from several divisions: its entry order is each
   * division's in turn, so it ranks nothing across them — and no row may
   * tease a division leader as the conference's.
   */
  spansDivisions?: boolean;
  name: string;
  entries: ConferenceStanding[];
}

/** One conference with its member teams (alphabetical), for browsing. */
export interface ConferenceTeams {
  id?: string;
  league: League;
  name: string;
  teams: Team[];
  /** A row identity that can't collide across leagues — `id` alone would
   * hand a list holding both the SEC and the AFC two rows claiming to be
   * number 8. */
  rowId: string;
}

export interface RankedTeam {
  rank: number;
  team: Team;
  record: string;
  previousRank?: number;
  votes: number;
  firstPlaceVotes?: number;
}

/** One poll as ESPN publishes it, ranks included. */
export interface Poll {
  id: string;
  name: string;
  shortName?: string;
  type?: string;
  headline?: string;
  ranks: RankedTeam[];
}

export interface TeamStats {
  totalYards: number;
  passingYards: number;
  rushingYards: number;
  turnovers: number;
  penalties: number;
  penaltyYards: number;
  firstDowns: number;
  thirdDownEfficiency: string; // "5-12"
  fourthDownEfficiency: string; // "1-2"
  timeOfPossession: string; // "32:15"
  redZoneEfficiency: string; // "2-3"
  sacks: number;
  interceptions: number;
  fumbles: number;
}

/** One side's leader in a stat category. */
export interface GameLeader {
  name: string;
  statLine: string;
  headshotUrl?: string;
}

/** A leader category ("Passing") with both sides filled in where known. */
export interface LeaderCategory {
  id: string;
  label: string;
  away?: GameLeader;
  home?: GameLeader;
}

/** One scoring play, chronological — the detail page's Scoring card rows. */
export interface ScoringPlayItem {
  id: string;
  /** Period the play happened in (1–4, 5 = OT, 6 = 2OT, …). */
  quarter?: number;
  /** Game clock at the score, e.g. "8:55". */
  clock?: string;
  /** "TD", "FG" — ESPN's play-type abbreviation. */
  typeAbbreviation?: string;
  /** The play text: "Jayden Maiava 1 Yd Run (Caden Chittenden Kick)". */
  text?: string;
  /** Running score after the play. */
  awayScore?: number;
  homeScore?: number;
}

/** One drive, scoring or not. */
export interface GameDrive {
  id: string;
  teamId?: string;
  result?: string;
  isScore: boolean;
  summary?: string;
  quarter?: number;
  /** Chronological, as ESPN ships them. Empty leaves a drive row
   *  unexpandable rather than opening onto nothing. */
  plays?: PlayItem[];
}

/** Which side of the matchup a scoring play's points belong to. Read off the
 *  change in the running score rather than off the drive's team: a pick six
 *  and a kick return both score for the side that wasn't on offense. */
export type ScoringSide = "away" | "home";

/**
 * One play. Football's live inside their drive; every other league's arrive
 * in a flat feed, because ESPN ships no drives for them — carrying football's
 * twice would print the same rows in two places.
 */
export interface PlayItem {
  id: string;
  /** ESPN's own narration. */
  text?: string;
  /** The down the play began on, ESPN's string: "1st & 10 at IU 5". */
  downDistanceText?: string;
  /** The down the play *left* behind, short form: "2nd & 4". */
  nextDownDistanceText?: string;
  /** Where the ball sits after the play — "WSU 26". */
  possessionText?: string;
  /** Distance from the offense's target end zone once the play ended. */
  yardsToEndzone?: number;
  clock?: string;
  period?: number;
  /** "Pass Reception", "Field Goal Good". */
  typeText?: string;
  isScoringPlay: boolean;
  awayScore?: number;
  homeScore?: number;
  /** Stamped at the transform boundary from the change in the running
   *  score. Absent on every non-scoring play, and on a scoring play whose
   *  numbers ESPN didn't ship. */
  scoringSide?: ScoringSide;
  /** Whose play it was, where the payload says — the flat feed only. */
  teamId?: string;
}

/**
 * The live situation — ESPN's Gamecast strip, derived from the drive in
 * progress. Every field is optional inside the payload, so a half-filled
 * situation renders the lines it has and drops the ones it doesn't.
 */
export interface GameSituation {
  possessionTeamId?: string;
  /** "2nd & 4". */
  downDistanceText?: string;
  /** "WSU 26" — the ball's spot. */
  possessionText?: string;
  /** The drive so far: "1 play, 6 yards, 0:05". */
  driveSummary?: string;
  /** ESPN's narration of the play that just ended. */
  lastPlayText?: string;
  /**
   * Where the ball sits, 0 at the away team's own goal line and 1 at the
   * home team's. Absent when the payload gave no distance, which leaves the
   * field bar off and the rest of the strip standing.
   */
  fieldPosition?: number;
  /** True when the offence is moving toward the home end zone. */
  drivingRight: boolean;
}

/**
 * One team's player box score.
 *
 * ESPN ships a category per stat group with its own column headers, and we
 * carry those headers through rather than naming columns ourselves —
 * **because the column set changes during the game**. A live `passing` group
 * has five columns and the same group has six once the game is final (QBR
 * only lands at the end), so anything hardcoded would misalign every row
 * mid-game, which is the one thing a stats table must never do.
 */
export interface BoxScoreTeam {
  teamId: string;
  categories: BoxScoreCategory[];
}

export interface BoxScoreCategory {
  /** ESPN's group name: "passing", "kickReturns". */
  id: string;
  /** "Passing", "Kick Returns". */
  label: string;
  columns: string[];
  players: BoxScorePlayer[];
  /** ESPN's team totals row. Empty when it doesn't match `columns`. */
  totals: string[];
}

export interface BoxScorePlayer {
  id: string;
  name: string;
  jersey?: string;
  headshotUrl?: string;
  /** Positionally paired with the owning category's `columns`. */
  stats: string[];
}

export interface GameDetail {
  game: Game;
  homeStats: TeamStats;
  awayStats: TeamStats;
  // Optional summary extras (absent in mock data; populated from ESPN).
  attendance?: number;
  venueCapacity?: number;
  venueSurface?: "grass" | "turf";
  weatherCondition?: string;
  weatherTemperature?: number;
  leaders?: LeaderCategory[];
  drives?: GameDrive[];
  scoringPlays?: ScoringPlayItem[];
  /** One entry per team. Empty is what hides the Box score tab. */
  boxScore?: BoxScoreTeam[];
  /** The flat play feed, oldest first — only ever populated for leagues
   *  with no drives to group by. */
  plays?: PlayItem[];
  /**
   * The possession in progress, live games only — ESPN's `drives.current`.
   * Absent the moment a game is final (verified live: a final game's
   * `drives` object carries `previous` and nothing else), which is what
   * retires the Gamecast strip without a second condition.
   */
  situation?: GameSituation;
}

/** The scoreboard response: the week strip's slots plus the slate. */
export interface Scoreboard {
  league: League;
  seasonYear?: number;
  seasonType?: number;
  currentWeekNumber?: number;
  weeks: WeekSlot[];
  games: Game[];
}

/**
 * One team's season: identity, record, and their games. `record`/`standing`
 * are trusted only when ESPN's summaries describe the requested season;
 * `derivedRecord` (W-L counted from final results) is the honest record for
 * a past season.
 */
/**
 * A team's home ground, derived from the season it already fetched.
 *
 * ESPN ships a venue on every competition of a team schedule, played or
 * not, so the home ground costs no request — it is the venue the team's
 * own non-neutral home dates keep naming.
 *
 * No capacity and no surface here on purpose: ESPN publishes no capacity
 * anywhere (sampled live 2026-09-10 across all four leagues), and the
 * schedule payload carries neither `grass` nor a venue id to go looking
 * with. A field that can never render is worse than no field.
 */
export interface TeamVenue {
  name: string;
  /** "Athens, GA" — whatever of the address ESPN shipped, joined. */
  city?: string;
  /** Home dates at this ground this season, played or still to come. */
  homeGames: number;
  /** How many of those have a published gate — the average's denominator. */
  countedGames: number;
  /** Mean announced attendance, absent until a home date has been played. */
  averageAttendance?: number;
}

export interface TeamScheduleData {
  team?: Team;
  record?: string;
  standing?: string;
  year?: number;
  games: Game[];
  derivedRecord?: string;
  /** Where this team plays. Absent for a season with no home date in it. */
  homeVenue?: TeamVenue;
}

// Grouped game structures for the scores page
export interface DayGames {
  date: string; // ISO date string (YYYY-MM-DD)
  label: string; // "Saturday, October 12"
  conferenceGroups: ConferenceGameGroup[];
}

export interface ConferenceGameGroup {
  conference: Conference;
  games: Game[];
}

// --- Roster ---
// The web twin of iOS `TeamRoster` (StatSideShared/Models/TeamRoster.swift).

/**
 * One team's current roster: the head coach and the players, in whatever
 * groups the provider ships them.
 *
 * **Current only.** ESPN's roster endpoint has no season axis — `season=2019`,
 * `season=2024` and `season=2025` all answer 200, echo the season back, and
 * carry zero athletes (probed live 2026-09-10 for iOS and re-probed
 * 2026-09-11 here). So there is no `year` and the Roster tab shows no season
 * chip: a past season's roster isn't something we can be wrong about, it's
 * something we can't ask for.
 */
export interface TeamRoster {
  coach?: RosterCoach;
  groups: RosterGroup[];
}

/**
 * A titled run of players — ESPN's own grouping, never ours.
 *
 * The NFL and college football ship six lowercase codes (offense, defense,
 * specialTeam, injuredReserveOrOut, suspended, practiceSquad); the NHL ships
 * display-ready names ("Centers", "Goalies"); the NBA ships no grouping at
 * all, so its whole roster arrives as one group. Deriving guards and forwards
 * from each athlete's position would be inventing a structure the payload
 * doesn't have — the same rule that keeps drives and downs off a basketball
 * game page.
 */
export interface RosterGroup {
  /** Display name, already resolved from the provider's code. */
  name: string;
  players: RosterPlayer[];
}

export interface RosterCoach {
  name: string;
}

/**
 * One player. Everything but the id and the name is optional, because ESPN
 * omits plenty: no jersey on 5 of 76 NFL players, none on 10 of 18 NBA
 * preseason ones, and no `age` whatsoever on a college football roster
 * (0 of 100 — college keeps a class year instead).
 */
export interface RosterPlayer {
  id: string;
  name: string;
  jersey?: string;
  /** Position abbreviation — "QB", "LW", "G". */
  position?: string;
  /** The position spoken out loud, for a screen reader ("Quarterback"). */
  positionName?: string;
  /** ESPN's own formatting, which already carries the units: `6' 2"`. */
  height?: string;
  /** Likewise: `225 lbs`. */
  weight?: string;
  age?: number;
  /** College football's answer to age — "FR", "SO", "JR", "SR". */
  classAbbreviation?: string;
  headshotUrl?: string;
  /** "Questionable", "Out". Only the NFL ships these, and only for the
   *  handful of players carrying one. */
  injuryStatus?: string;
}

/** Nothing to show — which is what renders "Roster TBA" rather than a
 *  stack of empty cards. */
export function rosterIsEmpty(roster: TeamRoster): boolean {
  return (
    roster.coach === undefined &&
    roster.groups.every((group) => group.players.length === 0)
  );
}
