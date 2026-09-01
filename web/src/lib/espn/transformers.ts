// DTO → domain mapping — the single mapping home for ESPN's shapes, a
// faithful port of the iOS app's ESPNMapper (StatSideShared/Networking/
// ESPNClient.swift). Rules that matter:
// - Status switches on `status.type.state` FIRST ("pre"/"in"/"post"), never
//   on type.name: an unknown live status name stays live.
// - Halftime/end-of-period arrive as `state: "in"` with the clock parked at
//   0:00; only the type name says the clock isn't running.
// - Malformed events are dropped (null), never thrown.
// - Standings keep ESPN's order (it encodes tiebreakers) unless a complete,
//   unique playoffSeed set says otherwise. Never sorted from records.

import type {
  Team,
  Game,
  GameStatus,
  GameTeam,
  Venue,
  ConferenceStanding,
  ConferenceStandingsGroup,
  ConferenceTeams,
  RankedTeam,
  Poll,
  GameDetail,
  GameDrive,
  LeaderCategory,
  GameLeader,
  ScoringPlayItem,
  TeamStats,
  TeamScheduleData,
} from "@/lib/types";
import type { LivePhase } from "@/lib/format";
import type { WeekSlot } from "@/lib/season";
import { makeWeekSlot } from "@/lib/season";
import { conferenceName, tier } from "@/lib/conferences";
import type {
  EspnScoreboardResponse,
  EspnEvent,
  EspnCompetitor,
  EspnTeam,
  EspnTeamGroups,
  EspnStatus,
  EspnGameSummaryResponse,
  EspnHeaderCompetitor,
  EspnRanking,
  EspnRank,
  EspnRankingsResponse,
  EspnStandingsResponse,
  EspnStandingsEntry,
  EspnScheduleResponse,
  EspnScheduleEvent,
  EspnScheduleCompetitor,
  EspnBoxscoreTeam,
  EspnDrive,
  EspnScoringPlay,
  EspnTeamLeaders,
  EspnVenue,
} from "./types";
import { flexibleNumber } from "./types";
import { ESPN_LOGO_BASE } from "@/lib/constants";

// --- Small shared helpers ---

function nonEmpty(value: string | null | undefined): string | undefined {
  return value ? value : undefined;
}

/** Curated ranks: only 1…25 survive (ESPN parks unranked teams at 99). */
function clampRank(value: number | undefined): number | undefined {
  return value !== undefined && value >= 1 && value <= 25 ? value : undefined;
}

/**
 * The team's conference from its most specific group. When the group IS the
 * conference, its parent is FBS (80) — never walk up. When it's a division,
 * the parent is the conference.
 */
export function conferenceIdFromGroups(
  groups: EspnTeamGroups | undefined
): number | undefined {
  if (!groups) return undefined;
  return groups.isConference === true
    ? flexibleNumber(groups.id)
    : flexibleNumber(groups.parent?.id);
}

// --- Status mapping ---

/**
 * State-first status mapping. `type.state` is the authority: "pre"/"in"/
 * "post". Only within a known state does `type.name` refine (halftime, end
 * of period, postponed vs. cancelled). An unknown name in state "in" stays
 * live — ESPN invents status names, and a live game must never render as
 * scheduled.
 */
export function mapStatus(status: EspnStatus | undefined): {
  status: GameStatus;
  livePhase?: LivePhase;
} {
  const name = status?.type?.name;
  switch (status?.type?.state) {
    case "pre":
      return { status: "scheduled" };
    case "in":
      if (name === "STATUS_HALFTIME") {
        return { status: "halftime", livePhase: "halftime" };
      }
      if (name === "STATUS_END_PERIOD") {
        return { status: "end_period", livePhase: "endOfPeriod" };
      }
      return { status: "in_progress", livePhase: "playing" };
    case "post":
      if (status?.type?.completed === true) return { status: "complete" };
      return { status: statusFromName(name, "postponed") };
    default:
      return { status: statusFromName(name, "scheduled") };
  }
}

function statusFromName(
  name: string | undefined,
  fallback: GameStatus
): GameStatus {
  switch (name) {
    case "STATUS_POSTPONED":
      return "postponed";
    case "STATUS_CANCELED":
    case "STATUS_CANCELLED":
      return "cancelled";
    case "STATUS_DELAYED":
    case "STATUS_RAIN_DELAY":
      return "delayed";
    default:
      return fallback;
  }
}

// --- Team ---

export function transformTeam(espnTeam: EspnTeam): Team | null {
  if (!espnTeam.id) return null;
  const espnId = Number(espnTeam.id);
  if (!Number.isFinite(espnId)) return null;

  const numericConferenceId =
    conferenceIdFromGroups(espnTeam.groups) ??
    flexibleNumber(espnTeam.conferenceId);
  const registryName = conferenceName(numericConferenceId);
  const groupName =
    registryName !== "Other"
      ? registryName
      : (espnTeam.groups?.shortName ?? espnTeam.groups?.name);

  return {
    id: espnTeam.id,
    espnId,
    name: espnTeam.name ?? espnTeam.nickname ?? "",
    school: espnTeam.location ?? espnTeam.displayName ?? "—",
    abbreviation: espnTeam.abbreviation ?? "",
    conferenceId:
      numericConferenceId !== undefined ? String(numericConferenceId) : "0",
    conferenceName: groupName ?? "Independent",
    division: "FBS",
    color: espnTeam.color ? `#${espnTeam.color}` : undefined,
    altColor: espnTeam.alternateColor
      ? `#${espnTeam.alternateColor}`
      : undefined,
    logoUrl:
      espnTeam.logo ??
      espnTeam.logos?.[0]?.href ??
      `${ESPN_LOGO_BASE}/${espnId}.png`,
  };
}

// --- GameTeam ---

function transformGameTeam(comp: EspnCompetitor): GameTeam | null {
  if (!comp.team) return null;
  const team = transformTeam(comp.team);
  if (!team) return null;

  const parsedScore =
    comp.score !== undefined ? parseInt(comp.score, 10) : Number.NaN;
  const record = comp.records?.find(
    (r) => r.type === "total" || r.name === "overall"
  )?.summary;

  return {
    team,
    score: Number.isNaN(parsedScore) ? null : parsedScore,
    ranking: clampRank(flexibleNumber(comp.curatedRank?.current)),
    record: nonEmpty(record),
    isWinner: comp.winner,
    linescores: comp.linescores
      ?.map((ls) => ls.value)
      .filter((v): v is number => v !== undefined),
  };
}

// --- Venue ---

function transformVenue(venue: EspnVenue | undefined): Venue {
  return {
    name: venue?.fullName ?? "TBD",
    city: venue?.address?.city ?? "",
    state: venue?.address?.state ?? "",
  };
}

// --- Game (scoreboard event) ---

/** Malformed events map to null and are filtered out, never thrown. */
export function transformEvent(
  event: EspnEvent,
  context?: { seasonYear?: number }
): Game | null {
  const comp = event.competitions?.[0];
  if (!event.id || !comp) return null;

  const homeComp = comp.competitors?.find((c) => c.homeAway === "home");
  const awayComp = comp.competitors?.find((c) => c.homeAway === "away");
  if (!homeComp || !awayComp) return null;
  const homeTeam = transformGameTeam(homeComp);
  const awayTeam = transformGameTeam(awayComp);
  if (!homeTeam || !awayTeam) return null;

  const status = comp.status ?? event.status;
  const { status: gameStatus, livePhase } = mapStatus(status);
  const possessionId = comp.situation?.possession;

  return {
    id: event.id,
    status: gameStatus,
    scheduledAt: event.date ?? comp.date ?? "",
    venue: transformVenue(comp.venue),
    homeTeam,
    awayTeam,
    // ESPN sends "" (not nil) before a broadcast is announced — normalized
    // so every broadcast surface stays honest instead of rendering an
    // empty TV line.
    broadcast:
      nonEmpty(comp.broadcast) ?? nonEmpty(comp.broadcasts?.[0]?.names?.[0]),
    clock: status?.displayClock,
    quarter: status?.period || undefined,
    possession:
      possessionId !== undefined &&
      possessionId === (homeComp.id ?? homeComp.team?.id)
        ? "home"
        : possessionId !== undefined &&
            possessionId === (awayComp.id ?? awayComp.team?.id)
          ? "away"
          : undefined,
    week: event.week?.number ?? 0,
    seasonYear: event.season?.year ?? context?.seasonYear ?? 0,
    conferenceGame: comp.conferenceCompetition ?? false,
    timeTBD: comp.timeValid === false,
    seasonType: event.season?.type,
    livePhase,
    statusDetail: status?.type?.shortDetail ?? status?.type?.detail,
  };
}

export function transformScoreboard(
  events: EspnEvent[],
  context?: { seasonYear?: number }
): Game[] {
  return events
    .map((event) => transformEvent(event, context))
    .filter((game): game is Game => game !== null);
}

// --- Calendar → WeekSlot[] ---

export function transformCalendar(
  response: EspnScoreboardResponse
): WeekSlot[] {
  const periods = response.leagues?.[0]?.calendar ?? [];
  const slots: WeekSlot[] = [];
  for (const period of periods) {
    const seasonType = flexibleNumber(period.value);
    if (seasonType !== 2 && seasonType !== 3) continue;
    for (const entry of period.entries ?? []) {
      const value = flexibleNumber(entry.value);
      if (value === undefined) continue;
      const label = entry.label ?? entry.alternateLabel ?? `Week ${value}`;
      slots.push(
        makeWeekSlot({
          label,
          // Regular weeks compact to "Wk {n}"; postseason slots keep their
          // names (Bowls, CFP).
          shortLabel:
            seasonType === 2 ? `Wk ${value}` : (entry.alternateLabel ?? label),
          seasonType,
          value,
          startDate: entry.startDate,
          endDate: entry.endDate,
        })
      );
    }
  }
  return slots;
}

// --- Rankings ---

export function transformRankedTeam(rank: EspnRank): RankedTeam | null {
  if (!rank.team || rank.current === undefined) return null;
  const team = transformTeam(rank.team);
  if (!team) return null;
  return {
    rank: rank.current,
    team,
    record: rank.recordSummary ?? "",
    previousRank: rank.previous,
    votes: rank.points ?? 0,
    firstPlaceVotes: rank.firstPlaceVotes,
  };
}

export function transformPoll(ranking: EspnRanking): Poll | null {
  if (!ranking.name) return null;
  return {
    id: ranking.id ?? ranking.name,
    name: ranking.name,
    shortName: ranking.shortName,
    type: ranking.type,
    // "2026 AP Poll: Preseason" over the long headline, which says
    // "Rankings" twice under a Rankings title.
    headline: ranking.shortHeadline ?? ranking.headline,
    ranks: (ranking.ranks ?? [])
      .map(transformRankedTeam)
      .filter((rank): rank is RankedTeam => rank !== null),
  };
}

export function transformPolls(response: EspnRankingsResponse): Poll[] {
  return (response.rankings ?? [])
    .map(transformPoll)
    .filter((poll): poll is Poll => poll !== null);
}

// --- Standings ---

function parseRecordString(record: string | undefined): {
  wins: number;
  losses: number;
} {
  const match = record ? /^(\d+)-(\d+)/.exec(record) : null;
  return match
    ? { wins: Number(match[1]), losses: Number(match[2]) }
    : { wins: 0, losses: 0 };
}

function transformStandingsEntry(
  entry: EspnStandingsEntry,
  groupId: number | undefined,
  index: number
): ConferenceStanding | null {
  if (!entry.team) return null;
  const team = transformTeam(entry.team);
  if (!team) return null;

  const stat = (type: string) => entry.stats?.find((s) => s.type === type);

  const conferenceRecord =
    stat("vsconf")?.summary ?? stat("vsconf")?.displayValue ?? undefined;
  const overallRecord =
    stat("total")?.summary ?? stat("total")?.displayValue ?? undefined;
  const streak = stat("streak")?.displayValue;
  const rawSeed = stat("playoffseed")?.value;
  const playoffSeed = rawSeed != null ? Math.trunc(rawSeed) : undefined;

  const conf = parseRecordString(conferenceRecord);
  const overall = parseRecordString(overallRecord);
  const streakMatch = streak ? /^([WL])(\d+)$/i.exec(streak) : null;

  return {
    team: {
      ...team,
      conferenceId: groupId !== undefined ? String(groupId) : team.conferenceId,
      conferenceName:
        groupId !== undefined ? conferenceName(groupId) : team.conferenceName,
    },
    conferenceWins: conf.wins,
    conferenceLosses: conf.losses,
    overallWins: overall.wins,
    overallLosses: overall.losses,
    conferenceRank: playoffSeed ?? index + 1,
    streakType: streakMatch
      ? (streakMatch[1].toUpperCase() as "W" | "L")
      : undefined,
    streakLength: streakMatch ? Number(streakMatch[2]) : undefined,
    conferenceRecord,
    overallRecord,
    streak,
    playoffSeed,
  };
}

/**
 * ESPN's placement stat beats payload order when it's complete: past-season
 * responses come back sorted by overall record, but every entry carries
 * `playoffSeed`, the tiebreaker-aware standings position. A conference with
 * missing or duplicated seeds keeps payload order — imperfect but not
 * invented. NEVER sorted from records: tiebreakers aren't derivable.
 */
export function seedOrdered(
  entries: ConferenceStanding[]
): ConferenceStanding[] {
  const seeds = entries
    .map((entry) => entry.playoffSeed)
    .filter((seed): seed is number => seed !== undefined);
  const complete =
    seeds.length === entries.length &&
    seeds.every((seed) => seed >= 1) &&
    new Set(seeds).size === seeds.length;
  if (!complete) return entries;
  return [...entries].sort(
    (a, b) => (a.playoffSeed ?? 0) - (b.playoffSeed ?? 0)
  );
}

function tierNameSort(
  a: { id?: string; name: string },
  b: { id?: string; name: string }
): number {
  const rank = (id: string | undefined) => {
    switch (tier(id !== undefined ? Number(id) : undefined)) {
      case "power4":
        return 0;
      case "group5":
        return 1;
      case "independent":
        return 2;
      case "other":
        return 3;
    }
  };
  const [ra, rb] = [rank(a.id), rank(b.id)];
  if (ra !== rb) return ra - rb;
  return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
}

/**
 * One group per conference child of the FBS payload, in tier-then-name
 * order. Empty conferences are KEPT — offseason responses can have zero
 * entries and the page needs to say "Standings TBA", not error.
 */
export function transformStandings(
  response: EspnStandingsResponse
): ConferenceStandingsGroup[] {
  return (response.children ?? [])
    .map((group) => {
      const numericId = flexibleNumber(group.id);
      const registryName = conferenceName(numericId);
      const name =
        registryName !== "Other"
          ? registryName
          : (group.shortName ?? group.name ?? "Conference");
      const entries = (group.standings?.entries ?? [])
        .map((entry, index) => transformStandingsEntry(entry, numericId, index))
        .filter((entry): entry is ConferenceStanding => entry !== null);
      return {
        id: numericId !== undefined ? String(numericId) : "",
        name,
        entries: seedOrdered(entries),
      };
    })
    .sort(tierNameSort);
}

/**
 * The browse sibling of `transformStandings` over the same response:
 * alphabetical rosters. Empty conferences are KEPT — ESPN ships the Sun
 * Belt (group 37) with zero standings entries, and dropping it would
 * silently list 10 FBS conferences instead of 11. Each surface decides
 * how to render an empty roster; the transformer never hides a
 * conference that exists.
 */
export function transformConferenceTeams(
  response: EspnStandingsResponse
): ConferenceTeams[] {
  return (response.children ?? [])
    .map((group) => {
      const numericId = flexibleNumber(group.id);
      const registryName = conferenceName(numericId);
      const name =
        registryName !== "Other"
          ? registryName
          : (group.shortName ?? group.name ?? "Conference");
      const teams = (group.standings?.entries ?? [])
        .map((entry) => (entry.team ? transformTeam(entry.team) : null))
        .filter((team): team is Team => team !== null)
        .map((team) => ({
          ...team,
          conferenceId:
            numericId !== undefined ? String(numericId) : team.conferenceId,
          conferenceName:
            numericId !== undefined ? name : team.conferenceName,
        }))
        .sort((a, b) => (a.school < b.school ? -1 : a.school > b.school ? 1 : 0));
      return {
        id: numericId !== undefined ? String(numericId) : undefined,
        name,
        teams,
      };
    })
    .sort(tierNameSort);
}

// --- Team schedule ---

function transformScheduleGameTeam(
  comp: EspnScheduleCompetitor
): GameTeam | null {
  if (!comp.team) return null;
  const team = transformTeam(comp.team);
  if (!team) return null;

  // Score is an OBJECT on the schedule endpoint, not a string.
  const display = comp.score?.displayValue;
  const parsedDisplay = display !== undefined ? parseInt(display, 10) : NaN;
  const score = !Number.isNaN(parsedDisplay)
    ? parsedDisplay
    : comp.score?.value != null
      ? Math.trunc(comp.score.value)
      : null;

  const totalRecord = comp.record?.find((r) => r.type === "total");

  return {
    team,
    score,
    ranking: clampRank(flexibleNumber(comp.curatedRank?.current)),
    record: nonEmpty(totalRecord?.summary ?? totalRecord?.displayValue),
    isWinner: comp.winner ?? undefined,
  };
}

export function transformScheduleEvent(
  event: EspnScheduleEvent,
  context: { seasonYear?: number; seasonType?: number }
): Game | null {
  const comp = event.competitions?.[0];
  if (!event.id || !comp) return null;

  const homeComp = comp.competitors?.find((c) => c.homeAway === "home");
  const awayComp = comp.competitors?.find((c) => c.homeAway === "away");
  if (!homeComp || !awayComp) return null;
  const homeTeam = transformScheduleGameTeam(homeComp);
  const awayTeam = transformScheduleGameTeam(awayComp);
  if (!homeTeam || !awayTeam) return null;

  const status = comp.status;
  const { status: gameStatus, livePhase } = mapStatus(status);

  return {
    id: event.id,
    status: gameStatus,
    scheduledAt: event.date ?? comp.date ?? "",
    venue: transformVenue(comp.venue),
    homeTeam,
    awayTeam,
    broadcast: nonEmpty(comp.broadcasts?.[0]?.media?.shortName),
    clock: status?.displayClock,
    quarter: status?.period || undefined,
    week: event.week?.number ?? 0,
    seasonYear: context.seasonYear ?? 0,
    conferenceGame: false,
    timeTBD: (event.timeValid ?? comp.timeValid) === false,
    seasonType: context.seasonType,
    livePhase,
    statusDetail: status?.type?.shortDetail ?? status?.type?.detail,
  };
}

function deriveRecord(teamId: string, games: Game[]): string | undefined {
  let wins = 0;
  let losses = 0;
  for (const game of games) {
    if (game.status !== "complete") continue;
    const mine = [game.homeTeam, game.awayTeam].find(
      (side) => side.team.id === teamId
    );
    if (!mine || mine.isWinner === undefined) continue;
    if (mine.isWinner) wins += 1;
    else losses += 1;
  }
  return wins + losses > 0 ? `${wins}-${losses}` : undefined;
}

/**
 * Map a /teams/{id}/schedule payload (plus postseason extra events).
 * `recordSummary`/`standingSummary` always describe ESPN's *current*
 * season — under a past season's games they'd be this year's numbers, so
 * they only survive when `season.year === requestedSeason.year`.
 */
export function transformTeamSchedule(
  regular: EspnScheduleResponse,
  extraEvents: EspnScheduleEvent[] = []
): TeamScheduleData {
  const scheduleTeam = regular.team;
  let team: Team | undefined;
  if (scheduleTeam?.id) {
    const mapped = transformTeam({
      id: scheduleTeam.id,
      location: scheduleTeam.location,
      name: scheduleTeam.name,
      nickname: scheduleTeam.nickname,
      abbreviation: scheduleTeam.abbreviation,
      displayName: scheduleTeam.displayName,
      shortDisplayName: scheduleTeam.shortDisplayName,
      logo: scheduleTeam.logo,
      logos: scheduleTeam.logos,
      color: scheduleTeam.color,
      groups: scheduleTeam.groups,
    });
    team = mapped ?? undefined;
  }

  const year = regular.requestedSeason?.year;
  const games = [
    ...(regular.events ?? []).map((event) =>
      transformScheduleEvent(event, { seasonYear: year, seasonType: 2 })
    ),
    ...extraEvents.map((event) =>
      transformScheduleEvent(event, { seasonYear: year, seasonType: 3 })
    ),
  ]
    .filter((game): game is Game => game !== null)
    .sort((a, b) => {
      const at = a.scheduledAt ? Date.parse(a.scheduledAt) : Infinity;
      const bt = b.scheduledAt ? Date.parse(b.scheduledAt) : Infinity;
      return at - bt;
    });

  const summariesTrusted =
    regular.season?.year != null &&
    regular.season.year === regular.requestedSeason?.year;

  return {
    team,
    record: summariesTrusted
      ? nonEmpty(regular.team?.recordSummary)
      : undefined,
    standing: summariesTrusted
      ? nonEmpty(regular.team?.standingSummary)
      : undefined,
    year,
    games,
    derivedRecord: team ? deriveRecord(team.id, games) : undefined,
  };
}

// --- Game detail / summary ---

/**
 * Build the Game from a summary response's header — the header competitor
 * shape differs from the scoreboard's (score/rank are flexible numbers,
 * linescores carry displayValues).
 */
export function transformHeaderGame(
  gameId: string,
  summary: EspnGameSummaryResponse
): Game | null {
  const comp = summary.header?.competitions?.[0];
  if (!comp) return null;

  function side(homeAway: string): GameTeam | null {
    const competitor = comp?.competitors?.find(
      (c: EspnHeaderCompetitor) => c.homeAway === homeAway
    );
    if (!competitor?.team) return null;
    const team = transformTeam(competitor.team);
    if (!team) return null;
    const totalRecord = competitor.record?.find((r) => r.type === "total");
    return {
      team,
      score: flexibleNumber(competitor.score) ?? null,
      ranking: clampRank(flexibleNumber(competitor.rank)),
      record: nonEmpty(totalRecord?.summary ?? totalRecord?.displayValue),
      isWinner: competitor.winner,
      linescores: competitor.linescores
        ?.map((ls) =>
          ls.displayValue !== undefined ? parseInt(ls.displayValue, 10) : NaN
        )
        .filter((v) => !Number.isNaN(v)),
    };
  }

  const homeTeam = side("home");
  const awayTeam = side("away");
  if (!homeTeam || !awayTeam) return null;

  const { status, livePhase } = mapStatus(comp.status);
  return {
    id: gameId,
    status,
    scheduledAt: comp.date ?? "",
    venue: transformVenue(comp.venue ?? summary.gameInfo?.venue),
    homeTeam,
    awayTeam,
    // The summary header's broadcast shape differs from the scoreboard's:
    // `media.shortName` carries the network, not `names[]`.
    broadcast: nonEmpty(
      comp.broadcasts?.[0]?.names?.[0] ??
        comp.broadcasts?.[0]?.media?.shortName
    ),
    clock: comp.status?.displayClock,
    quarter: comp.status?.period || undefined,
    week: 0,
    seasonYear: 0,
    conferenceGame: comp.conferenceCompetition ?? false,
    timeTBD: comp.timeValid === false,
    livePhase,
    statusDetail: comp.status?.type?.shortDetail ?? comp.status?.type?.detail,
  };
}

function extractTeamStats(boxTeam: EspnBoxscoreTeam | undefined): TeamStats {
  function getStat(name: string): string {
    return (
      boxTeam?.statistics?.find((s) => s.name === name)?.displayValue ?? "0"
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

function transformDrive(drive: EspnDrive, index: number): GameDrive {
  return {
    id: drive.id ?? `drive-${index}`,
    teamId: drive.team?.id,
    result: nonEmpty(drive.displayResult?.trim() ?? drive.result?.trim()),
    isScore: drive.isScore ?? false,
    summary: drive.description,
    quarter: drive.start?.period?.number,
  };
}

function transformScoringPlay(
  play: EspnScoringPlay,
  index: number
): ScoringPlayItem {
  return {
    id: play.id ?? `scoring-${index}`,
    quarter: play.period?.number,
    clock: play.clock?.displayValue,
    typeAbbreviation: nonEmpty(play.type?.abbreviation),
    text: nonEmpty(play.text),
    awayScore: play.awayScore,
    homeScore: play.homeScore,
  };
}

/** The three offensive leader categories, one entry per category. */
const LEADER_CATEGORIES: { name: string; label: string }[] = [
  { name: "passingYards", label: "Passing" },
  { name: "rushingYards", label: "Rushing" },
  { name: "receivingYards", label: "Receiving" },
];

function transformLeaders(
  teamLeaders: EspnTeamLeaders[],
  awayTeamId: string | undefined,
  homeTeamId: string | undefined
): LeaderCategory[] {
  function leader(
    teamId: string | undefined,
    category: string
  ): GameLeader | undefined {
    if (teamId === undefined) return undefined;
    const entry = teamLeaders
      .find((tl) => tl.team?.id === teamId)
      ?.leaders?.find((lc) => lc.name === category)?.leaders?.[0];
    const name = entry?.athlete?.displayName ?? entry?.athlete?.shortName;
    if (!entry || !name) return undefined;
    return {
      name,
      statLine: entry.displayValue ?? "",
      headshotUrl: entry.athlete?.headshot?.href,
    };
  }

  const categories: LeaderCategory[] = [];
  for (const category of LEADER_CATEGORIES) {
    const away = leader(awayTeamId, category.name);
    const home = leader(homeTeamId, category.name);
    if (!away && !home) continue;
    categories.push({ id: category.name, label: category.label, away, home });
  }
  return categories;
}

export function transformGameSummary(
  gameId: string,
  game: Game,
  summary: EspnGameSummaryResponse
): GameDetail {
  const homeTeamEspnId = String(game.homeTeam.team.espnId);
  const awayTeamEspnId = String(game.awayTeam.team.espnId);
  const drives = summary.drives?.previous ?? [];

  // boxscore.teams has no homeAway on some responses; ESPN orders it
  // away-first, matching the scoreboard convention.
  const boxTeams = summary.boxscore?.teams ?? [];
  const awayBox = boxTeams.find((t) => t.homeAway === "away") ?? boxTeams[0];
  const homeBox = boxTeams.find((t) => t.homeAway === "home") ?? boxTeams[1];

  const venue = summary.gameInfo?.venue;

  return {
    game,
    homeStats: extractTeamStats(homeBox),
    awayStats: extractTeamStats(awayBox),
    attendance: summary.gameInfo?.attendance,
    venueCapacity: venue?.capacity,
    venueSurface:
      venue?.grass === undefined ? undefined : venue.grass ? "grass" : "turf",
    weatherCondition: summary.gameInfo?.weather?.displayValue,
    weatherTemperature:
      summary.gameInfo?.weather?.temperature != null
        ? Math.trunc(summary.gameInfo.weather.temperature)
        : undefined,
    leaders: transformLeaders(
      summary.leaders ?? [],
      awayTeamEspnId,
      homeTeamEspnId
    ),
    drives: drives.map(transformDrive),
    scoringPlays: (summary.scoringPlays ?? []).map(transformScoringPlay),
  };
}
