// Raw ESPN API response types — these map to the actual JSON structures
// returned by site.api.espn.com

export interface EspnScoreboardResponse {
  events: EspnEvent[];
  week: { number: number };
  season: { year: number; type: number };
}

export interface EspnEvent {
  id: string;
  date: string;
  name: string;
  shortName: string;
  season: { year: number; type: number };
  week: { number: number };
  competitions: EspnCompetition[];
  status: EspnStatus;
}

export interface EspnCompetition {
  id: string;
  date: string;
  venue: EspnVenue;
  competitors: EspnCompetitor[];
  status: EspnStatus;
  broadcasts?: EspnBroadcast[];
  situation?: EspnSituation;
  conferenceCompetition?: boolean;
}

export interface EspnVenue {
  id: string;
  fullName: string;
  address: {
    city: string;
    state: string;
  };
}

export interface EspnCompetitor {
  id: string;
  homeAway: "home" | "away";
  score?: string;
  winner?: boolean;
  curatedRank?: { current: number };
  records?: { name: string; summary: string }[];
  team: EspnTeam;
  linescores?: { value: number }[];
}

export interface EspnTeam {
  id: string;
  location: string; // "Alabama"
  name: string; // "Crimson Tide"
  abbreviation: string;
  displayName: string; // "Alabama Crimson Tide"
  shortDisplayName: string;
  color?: string;
  alternateColor?: string;
  logo?: string;
  logos?: { href: string }[];
  conferenceId?: string;
  groups?: {
    id: string;
    name: string;
    shortName: string;
    isConference: boolean;
  };
}

export interface EspnStatus {
  clock: number;
  displayClock: string;
  period: number;
  type: {
    id: string;
    name: string; // "STATUS_SCHEDULED", "STATUS_IN_PROGRESS", "STATUS_FINAL", etc.
    state: string; // "pre", "in", "post"
    completed: boolean;
    description: string;
    detail: string;
    shortDetail: string;
  };
}

export interface EspnBroadcast {
  market: string;
  names: string[];
}

export interface EspnSituation {
  possession?: string;
  downDistanceText?: string;
  lastPlay?: { text: string };
}

// Game Summary (detail) types
export interface EspnGameSummaryResponse {
  boxscore?: EspnBoxscore;
  drives?: EspnDrives;
  plays?: EspnPlay[];
  header?: {
    competitions: EspnCompetition[];
  };
}

export interface EspnBoxscore {
  teams: EspnBoxscoreTeam[];
  players?: unknown[];
}

export interface EspnBoxscoreTeam {
  team: EspnTeam;
  statistics: {
    name: string;
    displayValue: string;
    label: string;
  }[];
}

export interface EspnDrives {
  previous: EspnDrive[];
}

export interface EspnDrive {
  id: string;
  description: string;
  team: { id: string; displayName: string };
  start?: { period: { number: number }; text: string };
  end?: { period: { number: number }; text: string };
  timeElapsed: { displayValue: string };
  yards: number;
  offensivePlays: number;
  result: string;
  isScore: boolean;
}

export interface EspnPlay {
  id: string;
  text: string;
  type: { id: string; text: string };
  period: { number: number };
  clock: { displayValue: string };
  scoringPlay: boolean;
  team?: { id: string };
  start?: {
    down: number;
    distance: number;
    yardLine: number;
  };
  statYardage?: number;
}

// Rankings types
export interface EspnRankingsResponse {
  rankings: EspnRanking[];
}

export interface EspnRanking {
  name: string;
  type: string;
  ranks: EspnRank[];
}

export interface EspnRank {
  current: number;
  previous: number;
  team: EspnTeam;
  recordSummary: string;
  points: number;
}

// Roster types
export interface EspnRosterResponse {
  athletes: EspnAthleteGroup[];
}

export interface EspnAthleteGroup {
  position: string; // "Offense", "Defense", "Special Teams"
  items: EspnAthlete[];
}

export interface EspnAthlete {
  id: string;
  displayName: string;
  firstName: string;
  lastName: string;
  jersey?: string;
  position: {
    abbreviation: string;
    displayName: string;
  };
  headshot?: {
    href: string;
  };
}

// Standings types
export interface EspnStandingsResponse {
  children: EspnStandingsGroup[];
}

export interface EspnStandingsGroup {
  id: string;
  name: string;
  abbreviation: string;
  standings: {
    entries: EspnStandingsEntry[];
  };
}

export interface EspnStandingsEntry {
  team: EspnTeam;
  stats: { name: string; displayValue: string; value: number }[];
}
