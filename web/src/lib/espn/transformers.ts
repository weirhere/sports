import type {
  Team,
  Game,
  GameStatus,
  GameTeam,
  Venue,
  ConferenceStanding,
  RankedTeam,
  GameDetail,
  BoxScore,
  ScoringDrive,
  Play,
  TeamStats,
} from "@/lib/types";
import type {
  EspnEvent,
  EspnCompetitor,
  EspnTeam,
  EspnStatus,
  EspnGameSummaryResponse,
  EspnRank,
  EspnStandingsEntry,
  EspnBoxscoreTeam,
  EspnDrive,
  EspnPlay,
} from "./types";
import { ESPN_LOGO_BASE } from "@/lib/constants";

// --- Status mapping ---

function mapStatus(status: EspnStatus): GameStatus {
  const name = status.type.name;
  switch (name) {
    case "STATUS_SCHEDULED":
    case "STATUS_PRE_GAME":
      return "scheduled";
    case "STATUS_IN_PROGRESS":
      return "in_progress";
    case "STATUS_HALFTIME":
      return "halftime";
    case "STATUS_END_PERIOD":
      return "end_period";
    case "STATUS_FINAL":
    case "STATUS_FINAL_OVERTIME":
      return "complete";
    case "STATUS_POSTPONED":
      return "postponed";
    case "STATUS_CANCELLED":
      return "cancelled";
    case "STATUS_DELAYED":
    case "STATUS_RAIN_DELAY":
      return "delayed";
    default:
      return "scheduled";
  }
}

// --- Team ---

function transformTeam(espnTeam: EspnTeam): Team {
  const espnId = parseInt(espnTeam.id, 10);
  return {
    id: `espn-${espnTeam.id}`,
    espnId,
    name: espnTeam.name,
    school: espnTeam.location,
    abbreviation: espnTeam.abbreviation,
    conferenceId: espnTeam.groups?.id ?? "0",
    conferenceName: espnTeam.groups?.name ?? "Independent",
    division: "FBS", // Default; could be refined by checking group hierarchy
    color: espnTeam.color ? `#${espnTeam.color}` : undefined,
    altColor: espnTeam.alternateColor
      ? `#${espnTeam.alternateColor}`
      : undefined,
    logoUrl: `${ESPN_LOGO_BASE}/${espnId}.png`,
  };
}

// --- GameTeam ---

function transformGameTeam(comp: EspnCompetitor): GameTeam {
  const score = comp.score !== undefined ? parseInt(comp.score, 10) : null;
  const ranking =
    comp.curatedRank?.current && comp.curatedRank.current <= 25
      ? comp.curatedRank.current
      : undefined;
  const record = comp.records?.find((r) => r.name === "overall")?.summary;
  const linescores = comp.linescores?.map((ls) => ls.value);

  return {
    team: transformTeam(comp.team),
    score: isNaN(score as number) ? null : score,
    ranking,
    record,
    isWinner: comp.winner,
    linescores,
  };
}

// --- Venue ---

function transformVenue(
  venue?: { fullName: string; address: { city: string; state: string } }
): Venue {
  return {
    name: venue?.fullName ?? "TBD",
    city: venue?.address?.city ?? "",
    state: venue?.address?.state ?? "",
  };
}

// --- Game ---

export function transformEvent(event: EspnEvent): Game {
  const comp = event.competitions[0];
  const status = comp?.status ?? event.status;

  const home = comp.competitors.find((c) => c.homeAway === "home")!;
  const away = comp.competitors.find((c) => c.homeAway === "away")!;

  const broadcasts = comp.broadcasts?.flatMap((b) => b.names) ?? [];

  return {
    id: event.id,
    status: mapStatus(status),
    scheduledAt: event.date,
    venue: transformVenue(comp.venue),
    homeTeam: transformGameTeam(home),
    awayTeam: transformGameTeam(away),
    broadcast: broadcasts[0],
    clock: status.displayClock !== "0:00" ? status.displayClock : undefined,
    quarter: status.period || undefined,
    possession: comp.situation?.possession === home.id
      ? "home"
      : comp.situation?.possession === away.id
        ? "away"
        : undefined,
    week: event.week.number,
    seasonYear: event.season.year,
    conferenceGame: comp.conferenceCompetition ?? false,
  };
}

export function transformScoreboard(
  events: EspnEvent[]
): Game[] {
  return events.map(transformEvent);
}

// --- Rankings ---

export function transformRankedTeam(rank: EspnRank): RankedTeam {
  return {
    rank: rank.current,
    team: transformTeam(rank.team),
    record: rank.recordSummary,
    previousRank: rank.previous,
    votes: rank.points,
  };
}

// --- Standings ---

export function transformStandingsEntry(
  entry: EspnStandingsEntry
): ConferenceStanding {
  function getStat(name: string): number {
    const s = entry.stats.find((st) => st.name === name);
    return s ? s.value : 0;
  }

  function getStatStr(name: string): string {
    const s = entry.stats.find((st) => st.name === name);
    return s?.displayValue ?? "0";
  }

  const streakStr = getStatStr("streak");
  const streakType = streakStr.startsWith("W") ? "W" as const : "L" as const;
  const streakLength = parseInt(streakStr.replace(/[WL]/i, ""), 10) || 0;

  return {
    team: transformTeam(entry.team),
    conferenceWins: getStat("conferenceWins") || getStat("wins"),
    conferenceLosses: getStat("conferenceLosses") || getStat("losses"),
    overallWins: getStat("overall") ? 0 : getStat("wins"),
    overallLosses: getStat("overall") ? 0 : getStat("losses"),
    conferenceRank: getStat("rank") || 0,
    streakType,
    streakLength,
  };
}

// --- Game Detail / Summary ---

function extractTeamStats(boxTeam: EspnBoxscoreTeam): TeamStats {
  function getStat(name: string): string {
    return (
      boxTeam.statistics.find((s) => s.name === name)?.displayValue ?? "0"
    );
  }

  function getNum(name: string): number {
    return parseInt(getStat(name), 10) || 0;
  }

  return {
    totalYards: getNum("totalYards"),
    passingYards: getNum("netPassingYards"),
    rushingYards: getNum("rushingYards"),
    turnovers: getNum("turnovers"),
    penalties: getNum("totalPenaltiesYards") ? 0 : getNum("penalties"),
    penaltyYards: getNum("totalPenaltiesYards"),
    firstDowns: getNum("firstDowns"),
    thirdDownEfficiency: getStat("thirdDownEff"),
    fourthDownEfficiency: getStat("fourthDownEff"),
    timeOfPossession: getStat("possessionTime"),
    redZoneEfficiency: getStat("redZoneAttempts"),
    sacks: getNum("sacks"),
    interceptions: getNum("interceptions"),
    fumbles: getNum("fumblesLost"),
  };
}

function transformDrive(
  drive: EspnDrive,
  homeTeamId: string
): ScoringDrive {
  return {
    team: drive.team.id === homeTeamId ? "home" : "away",
    quarter: drive.start?.period?.number ?? 1,
    description: drive.description,
    plays: drive.offensivePlays,
    yards: drive.yards,
    timeOfPossession: drive.timeElapsed?.displayValue ?? "0:00",
    result: drive.result,
  };
}

function transformPlay(
  play: EspnPlay,
  homeTeamId: string
): Play {
  return {
    id: play.id,
    quarter: play.period.number,
    clock: play.clock.displayValue,
    down: play.start?.down,
    distance: play.start?.distance,
    yardLine: play.start?.yardLine,
    description: play.text,
    team: play.team?.id === homeTeamId ? "home" : "away",
    type: play.type.text.toLowerCase(),
    yards: play.statYardage,
    scoringPlay: play.scoringPlay,
  };
}

export function transformGameSummary(
  gameId: string,
  game: Game,
  summary: EspnGameSummaryResponse
): GameDetail {
  const homeTeamEspnId = String(game.homeTeam.team.espnId);

  // Box score
  const boxScore: BoxScore = {
    gameId,
    homeTeam: game.homeTeam,
    awayTeam: game.awayTeam,
    scoringDrives: (summary.drives?.previous ?? [])
      .filter((d) => d.isScore)
      .map((d) => transformDrive(d, homeTeamEspnId)),
  };

  // Plays
  const plays: Play[] = (summary.plays ?? []).map((p) =>
    transformPlay(p, homeTeamEspnId)
  );

  // Team stats
  const defaultStats: TeamStats = {
    totalYards: 0,
    passingYards: 0,
    rushingYards: 0,
    turnovers: 0,
    penalties: 0,
    penaltyYards: 0,
    firstDowns: 0,
    thirdDownEfficiency: "0-0",
    fourthDownEfficiency: "0-0",
    timeOfPossession: "0:00",
    redZoneEfficiency: "0-0",
    sacks: 0,
    interceptions: 0,
    fumbles: 0,
  };

  const boxTeams = summary.boxscore?.teams ?? [];
  // ESPN returns teams in order [away, home] in boxscore
  const homeStats = boxTeams.length >= 2
    ? extractTeamStats(boxTeams[1])
    : defaultStats;
  const awayStats = boxTeams.length >= 1
    ? extractTeamStats(boxTeams[0])
    : defaultStats;

  return {
    game,
    boxScore,
    plays,
    homeStats,
    awayStats,
  };
}
