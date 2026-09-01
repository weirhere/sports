// Raw ESPN API response types, mirrored defensively — the TS twin of the
// iOS app's ESPNDTOs.swift. The API is undocumented and can change without
// notice, so effectively EVERY field is optional: a missing field degrades
// the row, never crashes the page. No non-null assertions anywhere in this
// layer. These types never leave lib/espn — transformers map them to the
// domain models in @/lib/types.

/** ESPN sends some numerics as numbers, some as numeric strings. */
export type FlexibleNumber = number | string;

/** Parse a FlexibleNumber; undefined for anything non-numeric. */
export function flexibleNumber(
  value: FlexibleNumber | null | undefined
): number | undefined {
  if (value == null) return undefined;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

// --- Scoreboard ---

export interface EspnScoreboardResponse {
  leagues?: EspnLeague[];
  season?: { year?: number; type?: number };
  week?: { number?: number };
  events?: EspnEvent[];
}

export interface EspnLeague {
  calendar?: EspnCalendarPeriod[];
}

export interface EspnCalendarPeriod {
  label?: string;
  value?: FlexibleNumber;
  startDate?: string;
  endDate?: string;
  entries?: EspnCalendarEntry[];
}

export interface EspnCalendarEntry {
  label?: string;
  alternateLabel?: string;
  detail?: string;
  value?: FlexibleNumber;
  startDate?: string;
  endDate?: string;
}

export interface EspnEvent {
  id?: string;
  date?: string;
  name?: string;
  shortName?: string;
  season?: { year?: number; type?: number };
  week?: { number?: number };
  competitions?: EspnCompetition[];
  status?: EspnStatus;
}

export interface EspnCompetition {
  id?: string;
  date?: string;
  /** false = kickoff time unannounced; the date is a midnight placeholder. */
  timeValid?: boolean;
  neutralSite?: boolean;
  venue?: EspnVenue;
  competitors?: EspnCompetitor[];
  status?: EspnStatus;
  broadcast?: string;
  broadcasts?: EspnBroadcast[];
  situation?: EspnSituation;
  conferenceCompetition?: boolean;
}

export interface EspnVenue {
  id?: string;
  fullName?: string;
  address?: {
    city?: string;
    state?: string;
  };
  capacity?: number;
  grass?: boolean;
}

export interface EspnCompetitor {
  id?: string;
  homeAway?: string;
  score?: string;
  winner?: boolean;
  curatedRank?: { current?: FlexibleNumber };
  records?: { name?: string; type?: string; summary?: string }[];
  team?: EspnTeam;
  linescores?: { value?: number }[];
}

export interface EspnTeam {
  id?: string;
  location?: string; // "Alabama"
  name?: string; // "Crimson Tide"
  nickname?: string;
  abbreviation?: string;
  displayName?: string; // "Alabama Crimson Tide"
  shortDisplayName?: string;
  color?: string;
  alternateColor?: string;
  logo?: string;
  logos?: { href?: string }[];
  conferenceId?: FlexibleNumber;
  groups?: EspnTeamGroups;
}

/**
 * The team's most specific group — the conference itself
 * (`isConference: true`, parent = FBS 80) or, historically, a division
 * whose parent is the conference.
 */
export interface EspnTeamGroups {
  id?: FlexibleNumber;
  name?: string;
  shortName?: string;
  parent?: { id?: FlexibleNumber };
  isConference?: boolean;
}

export interface EspnStatus {
  clock?: number;
  displayClock?: string;
  period?: number;
  type?: {
    id?: string;
    name?: string; // "STATUS_SCHEDULED", "STATUS_HALFTIME", etc.
    state?: string; // "pre" | "in" | "post"
    completed?: boolean;
    description?: string;
    detail?: string;
    shortDetail?: string;
  };
}

export interface EspnBroadcast {
  market?: string;
  names?: string[];
}

export interface EspnSituation {
  possession?: string; // team id with the ball
  downDistanceText?: string;
  possessionText?: string;
  lastPlay?: { text?: string };
}

// --- Standings (the source of FBS conference membership) ---
// /apis/v2/.../standings?group=80 returns 11 conference children with exact
// rosters; the /teams endpoint has no conference data.

export interface EspnStandingsResponse {
  name?: string;
  children?: EspnStandingsGroup[];
}

export interface EspnStandingsGroup {
  id?: FlexibleNumber;
  name?: string;
  shortName?: string;
  abbreviation?: string;
  standings?: {
    entries?: EspnStandingsEntry[];
  };
}

export interface EspnStandingsEntry {
  team?: EspnTeam;
  stats?: EspnStandingsStat[];
}

/**
 * Each entry carries ~20 stats; `type` is the discriminator ("total",
 * "vsconf", "streak", "playoffseed", plus prefixed variants we ignore).
 */
export interface EspnStandingsStat {
  name?: string;
  type?: string;
  summary?: string | null;
  displayValue?: string;
  value?: number | null;
}

// --- Team schedule ---
// Quirks vs. the scoreboard shape: score is an OBJECT, record is an array
// under "record", status lives on the competition, broadcasts nest media.

export interface EspnScheduleResponse {
  /**
   * `season` is ESPN's CURRENT season; `requestedSeason` the one this
   * response actually contains (they differ for any past-season request).
   */
  season?: { year?: number; type?: number };
  requestedSeason?: { year?: number; type?: number };
  team?: EspnScheduleTeam;
  events?: EspnScheduleEvent[];
}

export interface EspnScheduleTeam {
  id?: string;
  location?: string;
  name?: string;
  nickname?: string;
  abbreviation?: string;
  displayName?: string;
  shortDisplayName?: string;
  logo?: string;
  logos?: { href?: string }[];
  color?: string;
  recordSummary?: string;
  standingSummary?: string;
  groups?: EspnTeamGroups;
}

export interface EspnScheduleEvent {
  id?: string;
  date?: string;
  timeValid?: boolean;
  name?: string;
  shortName?: string;
  week?: { number?: number; text?: string };
  seasonType?: { id?: string; type?: number };
  competitions?: EspnScheduleCompetition[];
}

export interface EspnScheduleCompetition {
  date?: string;
  timeValid?: boolean;
  neutralSite?: boolean;
  venue?: EspnVenue;
  status?: EspnStatus;
  competitors?: EspnScheduleCompetitor[];
  broadcasts?: EspnScheduleBroadcast[];
}

export interface EspnScheduleBroadcast {
  media?: { shortName?: string };
}

export interface EspnScheduleCompetitor {
  homeAway?: string;
  winner?: boolean | null;
  /** Score is an object on the schedule endpoint, not a string. */
  score?: { value?: number | null; displayValue?: string } | null;
  record?: EspnScheduleRecord[] | null;
  curatedRank?: { current?: FlexibleNumber };
  team?: EspnTeam;
}

export interface EspnScheduleRecord {
  type?: string;
  displayValue?: string;
  summary?: string;
}

// --- Game summary ---

export interface EspnGameSummaryResponse {
  header?: {
    competitions?: EspnHeaderCompetition[];
  };
  boxscore?: EspnBoxscore;
  scoringPlays?: EspnScoringPlay[];
  drives?: EspnDrives;
  plays?: EspnPlay[];
  leaders?: EspnTeamLeaders[];
  gameInfo?: EspnGameInfo;
}

export interface EspnHeaderCompetition {
  id?: string;
  date?: string;
  timeValid?: boolean;
  status?: EspnStatus;
  competitors?: EspnHeaderCompetitor[];
  venue?: EspnVenue;
  broadcasts?: EspnBroadcast[];
  conferenceCompetition?: boolean;
}

export interface EspnHeaderCompetitor {
  id?: string;
  homeAway?: string;
  winner?: boolean;
  score?: FlexibleNumber;
  rank?: FlexibleNumber;
  linescores?: { displayValue?: string }[];
  record?: EspnScheduleRecord[];
  team?: EspnTeam;
}

export interface EspnBoxscore {
  teams?: EspnBoxscoreTeam[];
}

export interface EspnBoxscoreTeam {
  team?: EspnTeam;
  homeAway?: string;
  statistics?: {
    name?: string;
    displayValue?: string;
    label?: string;
  }[];
}

export interface EspnScoringPlay {
  id?: string;
  period?: { number?: number };
  clock?: { displayValue?: string };
  text?: string;
  awayScore?: number;
  homeScore?: number;
  team?: { id?: string };
  type?: { text?: string; abbreviation?: string };
}

export interface EspnDrives {
  previous?: EspnDrive[];
}

export interface EspnDrive {
  id?: string;
  description?: string; // "5 plays, 20 yards, 2:39"
  displayResult?: string; // "Punt", not the ALL-CAPS `result`
  result?: string;
  isScore?: boolean;
  team?: { id?: string; displayName?: string };
  start?: { period?: { number?: number }; text?: string };
  end?: { period?: { number?: number }; text?: string };
  timeElapsed?: { displayValue?: string };
  yards?: number;
  offensivePlays?: number;
}

export interface EspnPlay {
  id?: string;
  text?: string;
  type?: { id?: string; text?: string };
  period?: { number?: number };
  clock?: { displayValue?: string };
  scoringPlay?: boolean;
  team?: { id?: string };
  start?: {
    down?: number;
    distance?: number;
    yardLine?: number;
  };
  statYardage?: number;
}

export interface EspnTeamLeaders {
  team?: { id?: string };
  leaders?: EspnLeaderCategory[];
}

export interface EspnLeaderCategory {
  name?: string;
  displayName?: string;
  leaders?: EspnLeaderEntry[];
}

export interface EspnLeaderEntry {
  displayValue?: string;
  athlete?: {
    displayName?: string;
    shortName?: string;
    jersey?: string;
    headshot?: { href?: string };
  };
}

export interface EspnGameInfo {
  venue?: EspnVenue;
  attendance?: number;
  weather?: { displayValue?: string; temperature?: number };
}

// --- Rankings ---

export interface EspnRankingsResponse {
  rankings?: EspnRanking[];
}

export interface EspnRanking {
  id?: string;
  name?: string;
  shortName?: string;
  type?: string;
  headline?: string;
  shortHeadline?: string;
  ranks?: EspnRank[];
}

export interface EspnRank {
  current?: number;
  previous?: number;
  points?: number;
  firstPlaceVotes?: number;
  trend?: string;
  recordSummary?: string;
  team?: EspnTeam;
}
