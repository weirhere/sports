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
import {
  collegeDivision,
  conferenceName,
  divisionForTeamId,
  parentOf,
  tier,
  tierRank,
} from "@/lib/conferences";
import {
  hasWeeks,
  leagueSpec,
  playsOnASurface,
  seasonYearFromEspn,
  teamLogoBase,
  type League,
} from "@/lib/leagues";
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
  EspnCoreRanking,
  EspnTeamsResponse,
  EspnStandingsResponse,
  EspnStandingsGroup,
  EspnStandingsEntry,
  EspnStandingsStat,
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
import { parseKickoff } from "@/lib/format";

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

export function transformTeam(
  espnTeam: EspnTeam,
  league: League
): Team | null {
  if (!espnTeam.id) return null;
  const espnId = Number(espnTeam.id);
  if (!Number.isFinite(espnId)) return null;

  // College football ships the conference id inline; the pro leagues ship
  // no group at all, so their teams are placed from the hardcoded registry
  // — without it every pro game falls into "Other" and a followed
  // conference matches nothing.
  const numericConferenceId =
    conferenceIdFromGroups(espnTeam.groups) ??
    flexibleNumber(espnTeam.conferenceId) ??
    divisionForTeamId(espnTeam.id, league);
  const registryName = conferenceName(numericConferenceId, league);
  const groupName =
    registryName !== "Other"
      ? registryName
      : (espnTeam.groups?.shortName ?? espnTeam.groups?.name);

  return {
    id: espnTeam.id,
    espnId,
    league,
    name: espnTeam.name ?? espnTeam.nickname ?? "",
    school: espnTeam.location ?? espnTeam.displayName ?? "—",
    abbreviation: espnTeam.abbreviation ?? "",
    conferenceId:
      numericConferenceId !== undefined ? String(numericConferenceId) : "0",
    conferenceName: groupName ?? "Independent",
    // Honors the `Division` type instead of asserting FBS over everything:
    // an FCS conference id now reads as FCS, and a pro team carries no
    // division at all because it has none.
    division: collegeDivision(numericConferenceId, league),
    color: espnTeam.color ? `#${espnTeam.color}` : undefined,
    altColor: espnTeam.alternateColor
      ? `#${espnTeam.alternateColor}`
      : undefined,
    logoUrl:
      espnTeam.logo ??
      espnTeam.logos?.[0]?.href ??
      `${teamLogoBase(league)}/${espnId}.png`,
  };
}

// --- GameTeam ---

function transformGameTeam(
  comp: EspnCompetitor,
  league: League
): GameTeam | null {
  if (!comp.team) return null;
  const team = transformTeam(comp.team, league);
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
  league: League,
  context?: { seasonYear?: number }
): Game | null {
  const comp = event.competitions?.[0];
  if (!event.id || !comp) return null;

  const homeComp = comp.competitors?.find((c) => c.homeAway === "home");
  const awayComp = comp.competitors?.find((c) => c.homeAway === "away");
  if (!homeComp || !awayComp) return null;
  const homeTeam = transformGameTeam(homeComp, league);
  const awayTeam = transformGameTeam(awayComp, league);
  if (!homeTeam || !awayTeam) return null;

  const status = comp.status ?? event.status;
  const { status: gameStatus, livePhase } = mapStatus(status);
  const possessionId = comp.situation?.possession;

  const timeTBD = comp.timeValid === false;

  return {
    id: event.id,
    league,
    status: gameStatus,
    scheduledAt: parseKickoff(event.date ?? comp.date ?? "", timeTBD),
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
    // ESPN sends `week: null` on every NBA and NHL event; a 0 there would
    // read as a real week number to anything grouping by one.
    week: hasWeeks(league) ? (event.week?.number ?? 0) : undefined,
    seasonYear: event.season?.year ?? context?.seasonYear ?? 0,
    conferenceGame: comp.conferenceCompetition ?? false,
    timeTBD,
    seasonType: event.season?.type,
    livePhase,
    statusDetail: status?.type?.shortDetail ?? status?.type?.detail,
    // The only place a college-football playoff round is named — its whole
    // postseason is one `seasontype=3` week, bowls and bracket together.
    headline: comp.notes?.[0]?.headline,
  };
}

export function transformScoreboard(
  events: EspnEvent[],
  league: League,
  context?: { seasonYear?: number }
): Game[] {
  return events
    .map((event) => transformEvent(event, league, context))
    .filter((game): game is Game => game !== null);
}

// --- Calendar → WeekSlot[] ---

/**
 * ESPN ships two different things under `leagues[].calendar`: football's
 * labelled week periods, or — for basketball and hockey, whose
 * `calendarType` is "day" — a flat list of ~229 ISO date strings. Only the
 * object form carries weeks, so anything else yields no slots rather than
 * throwing and taking the whole scoreboard down with it.
 */
export function transformCalendar(
  response: EspnScoreboardResponse
): WeekSlot[] {
  const raw = response.leagues?.[0]?.calendar;
  const periods = Array.isArray(raw)
    ? raw.filter((period): period is NonNullable<typeof period> =>
        period != null && typeof period === "object")
    : [];
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

export function transformRankedTeam(
  rank: EspnRank,
  league: League
): RankedTeam | null {
  if (!rank.team || rank.current === undefined) return null;
  const team = transformTeam(rank.team, league);
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

export function transformPoll(
  ranking: EspnRanking,
  league: League
): Poll | null {
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
      .map((rank) => transformRankedTeam(rank, league))
      .filter((rank): rank is RankedTeam => rank !== null),
  };
}

/**
 * Every team ESPN knows, by id — the site API's `/teams` directory.
 *
 * The core API's ranks carry their team as a `$ref` and nothing else, so the
 * names and marks have to come from somewhere. One request answers for all
 * 762 of them (FCS included), which is why flipping through past seasons
 * costs one request per poll and no more.
 */
export function transformTeamDirectory(
  response: EspnTeamsResponse | undefined,
  league: League
): Map<string, Team> {
  const byId = new Map<string, Team>();
  for (const sport of response?.sports ?? []) {
    for (const leagueEntry of sport.leagues ?? []) {
      for (const entry of leagueEntry.teams ?? []) {
        const team = entry.team ? transformTeam(entry.team, league) : null;
        if (team) byId.set(team.id, team);
      }
    }
  }
  return byId;
}

/** The team id out of a core-API `$ref` — ".../teams/84?lang=en". */
export function teamIdFromRef(ref: string | undefined): string | undefined {
  const match = ref ? /\/teams\/(\d+)/.exec(ref) : null;
  return match ? match[1] : undefined;
}

/**
 * A core-API ranking, resolved against the team directory.
 *
 * A rank whose team the directory can't name is **dropped**: a table of
 * dashes is worse than a shorter table, and an empty directory is treated by
 * the caller as the season failing rather than as a poll of nothing.
 */
export function transformCoreRanking(
  ranking: EspnCoreRanking,
  league: League,
  teams: Map<string, Team>
): Poll | null {
  if (!ranking.name) return null;
  const ranks: RankedTeam[] = [];
  for (const rank of ranking.ranks ?? []) {
    if (rank.current === undefined) continue;
    const id = teamIdFromRef(rank.team?.$ref);
    const team = id ? teams.get(id) : undefined;
    if (!team) continue;
    ranks.push({
      rank: rank.current,
      team,
      record: rank.record?.summary ?? "",
      previousRank: rank.previous,
      votes: rank.points ?? 0,
      firstPlaceVotes: rank.firstPlaceVotes,
    });
  }
  return {
    id: ranking.id ?? ranking.name,
    name: ranking.name,
    shortName: ranking.shortName,
    type: ranking.type,
    headline: ranking.shortHeadline ?? ranking.headline,
    ranks,
  };
}

export function transformPolls(
  response: EspnRankingsResponse,
  league: League
): Poll[] {
  return (response.rankings ?? [])
    .map((ranking) => transformPoll(ranking, league))
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

/**
 * Whether anyone has played a game in the season this response says it is
 * for.
 *
 * ESPN rolls its season *pointer* the moment the last one ends and keeps
 * serving the old table underneath it: probed live 2026-09-09, the NBA
 * standings were stamped 2026-27 and full of 2025-26 results three weeks
 * before a ball was tipped. So the stamp is no use and the start date is —
 * a season that opens in the future has no numbers, whatever numbers came
 * with it.
 *
 * True when ESPN ships no date at all: absence must never blank a table.
 */
export function seasonHasStarted(
  response: EspnStandingsResponse,
  now: Date = new Date()
): boolean {
  const raw = response.season?.startDate;
  if (!raw) return true;
  const start = Date.parse(raw);
  return !Number.isFinite(start) || start <= now.getTime();
}

/**
 * The overall record, in whatever shape the league writes one — "13-2" in
 * football and basketball, "50-23-9" in hockey, where a game lost in
 * overtime is still worth a point.
 *
 * **Composed from the counts, not read off `total`.** Two reasons, both
 * probed live 2026-09-09: a `level=3` response ships no `total` for the NBA
 * at all (only `wins` and `losses`), so a divisional page lost its W-L
 * column entirely; and the NHL's `total` is a *sentence* — "50-23-9, 109
 * PTS" — which is prose, not a column. `total.summary` stays the fallback
 * for a payload that ships no counts.
 */
function composedRecord(
  stat: (type: string) => EspnStandingsStat | undefined,
  league: League
): string | undefined {
  const count = (type: string) => {
    const raw = stat(type);
    const value = raw?.value ?? (raw?.displayValue ? Number(raw.displayValue) : undefined);
    return value != null && Number.isFinite(value) ? Math.trunc(value) : undefined;
  };
  const wins = count("wins");
  const losses = count("losses");
  if (wins !== undefined && losses !== undefined) {
    if (league === "nhl") {
      const otLosses = count("otlosses") ?? count("overtimelosses") ?? 0;
      return `${wins}-${losses}-${otLosses}`;
    }
    return `${wins}-${losses}`;
  }
  const total = stat("total");
  // Never the displayValue for hockey — that one is the sentence.
  return (
    total?.summary ?? (league === "nhl" ? undefined : total?.displayValue)
  ) ?? undefined;
}

function transformStandingsEntry(
  entry: EspnStandingsEntry,
  groupId: number | undefined,
  index: number,
  league: League,
  played: boolean
): ConferenceStanding | null {
  if (!entry.team) return null;
  const team = transformTeam(entry.team, league);
  if (!team) return null;

  const stat = (type: string) => entry.stats?.find((s) => s.type === type);

  const conferenceRecord =
    stat("vsconf")?.summary ?? stat("vsconf")?.displayValue ?? undefined;
  const overallRecord = composedRecord(stat, league);
  const streak = stat("streak")?.displayValue;
  const rawSeed = stat("playoffseed")?.value;
  const playoffSeed = rawSeed != null ? Math.trunc(rawSeed) : undefined;
  // What a merged league table ranks on. Football and basketball keep a
  // win percentage; the NHL keeps none and ranks on points instead, so a
  // league table there would otherwise fall to source order and come back
  // East's seeds then West's.
  const winPercent = stat("winpercent")?.value ?? undefined;
  const points = stat("points")?.value ?? undefined;
  const gamesPlayed = stat("gamesplayed")?.value ?? undefined;
  // ESPN already writes these the way a table shows them: ".732" with the
  // zero stripped, and "-" for the leader's games back.
  const winPercentText = stat("winpercent")?.displayValue;
  const gamesBehind = stat("gamesbehind")?.displayValue;

  const conf = parseRecordString(conferenceRecord);
  const overall = parseRecordString(overallRecord);
  const streakMatch = streak ? /^([WL])(\d+)$/i.exec(streak) : null;

  const identity = {
    team: {
      ...team,
      conferenceId: groupId !== undefined ? String(groupId) : team.conferenceId,
      conferenceName:
        groupId !== undefined
          ? conferenceName(groupId, league)
          : team.conferenceName,
    },
  };

  // The roster still stands — who is in this division is true all summer.
  // Only the numbers are last season's.
  if (!played) {
    return {
      ...identity,
      conferenceWins: 0,
      conferenceLosses: 0,
      overallWins: 0,
      overallLosses: 0,
      conferenceRank: index + 1,
    };
  }

  return {
    ...identity,
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
    winPercent,
    points: points != null ? Math.trunc(points) : undefined,
    gamesPlayed: gamesPlayed != null ? Math.trunc(gamesPlayed) : undefined,
    gamesBehind,
    winPercentText,
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
  b: { id?: string; name: string },
  league: League
): number {
  const rank = (id: string | undefined) =>
    tierRank(tier(id !== undefined ? Number(id) : undefined, league));
  const [ra, rb] = [rank(a.id), rank(b.id)];
  if (ra !== rb) return ra - rb;
  return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
}

/**
 * One group per conference child of the FBS payload, in tier-then-name
 * order. Empty conferences are KEPT — offseason responses can have zero
 * entries and the page needs to say "Standings TBA", not error.
 */
/**
 * One group's own table, without its children.
 *
 * A group with no entries still becomes a table: an offseason response can
 * have zero, and the page needs to say "Standings TBA" rather than error —
 * and ESPN ships the Sun Belt with none at all, which is what silently
 * dropped it from the list of 11 for a while.
 */
function transformStandingsGroup(
  group: EspnStandingsGroup,
  league: League,
  parentId: number | undefined,
  played: boolean
): ConferenceStandingsGroup {
  const numericId = flexibleNumber(group.id);
  const registryName = conferenceName(numericId, league);
  const name =
    registryName !== "Other"
      ? registryName
      : (group.shortName ?? group.name ?? "Conference");
  const entries = (group.standings?.entries ?? [])
    .map((entry, index) =>
      transformStandingsEntry(entry, numericId, index, league, played)
    )
    .filter((entry): entry is ConferenceStanding => entry !== null);
  return {
    id: numericId !== undefined ? String(numericId) : "",
    league,
    name,
    entries: played ? seedOrdered(entries) : entries,
    parentId,
  };
}

/**
 * Every group in the response, at whatever depth it sits.
 *
 * Walks the **whole tree** rather than collapsing to one depth or the
 * other, because a `level=3` response carries both: the conferences and
 * the divisions under them. Parentage comes from our own registry first
 * and from the payload's nesting only where the id is new — the registry
 * is the thing the rest of the app agrees with, and it knows that the
 * NFL's group 4 hangs under 8 whatever shape a given response arrives in.
 *
 * A group with children is still a group: the AFC is a real table as well
 * as the parent of four.
 */
export function transformStandings(
  response: EspnStandingsResponse,
  league: League
): ConferenceStandingsGroup[] {
  const tables: ConferenceStandingsGroup[] = [];
  const played = seasonHasStarted(response);

  const walk = (
    groups: readonly EspnStandingsGroup[],
    payloadParent: number | undefined
  ) => {
    for (const group of groups) {
      const id = flexibleNumber(group.id);
      // The registry's answer wins; the payload's nesting is the fallback
      // for an id it has never seen — 2019's "American Athletic - East"
      // is group 163, which no registry knows, and 151 is where it hangs.
      const parent = parentOf(id, league) ?? payloadParent;
      const children = group.children ?? [];
      const entries = group.standings?.entries ?? [];
      // A group that is purely a container contributes no table of its
      // own: its numbers live in its children, and `foldingDivisions` is
      // what merges them back into a row that names the conference.
      // Emitting it too would put an EMPTY "AFC" beside the real one.
      //
      // Guarded on having no entries rather than on having children, so a
      // response that ever carries both keeps what it carries.
      if (children.length === 0 || entries.length > 0) {
        tables.push(transformStandingsGroup(group, league, parent, played));
      }
      walk(children, id);
    }
  };
  walk(response.children ?? [], undefined);

  return tables.sort((a, b) => tierNameSort(a, b, league));
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
  response: EspnStandingsResponse,
  league: League
): ConferenceTeams[] {
  return (response.children ?? [])
    .map((group) => {
      const numericId = flexibleNumber(group.id);
      const registryName = conferenceName(numericId, league);
      const name =
        registryName !== "Other"
          ? registryName
          : (group.shortName ?? group.name ?? "Conference");
      const teams = (group.standings?.entries ?? [])
        .map((entry) => (entry.team ? transformTeam(entry.team, league) : null))
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
        league,
        name,
        teams,
        // `id` alone would hand a list holding both the SEC and the AFC two
        // rows claiming to be number 8 — which corrupts a keyed list into
        // blank card-sized gaps.
        rowId: numericId !== undefined ? `${league}:${numericId}` : `other-${name}`,
      };
    })
    .sort((a, b) => tierNameSort(a, b, league));
}

// --- Team schedule ---

function transformScheduleGameTeam(
  comp: EspnScheduleCompetitor,
  league: League
): GameTeam | null {
  if (!comp.team) return null;
  const team = transformTeam(comp.team, league);
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
  league: League,
  context: { seasonYear?: number; seasonType?: number }
): Game | null {
  const comp = event.competitions?.[0];
  if (!event.id || !comp) return null;

  const homeComp = comp.competitors?.find((c) => c.homeAway === "home");
  const awayComp = comp.competitors?.find((c) => c.homeAway === "away");
  if (!homeComp || !awayComp) return null;
  const homeTeam = transformScheduleGameTeam(homeComp, league);
  const awayTeam = transformScheduleGameTeam(awayComp, league);
  if (!homeTeam || !awayTeam) return null;

  const status = comp.status;
  const { status: gameStatus, livePhase } = mapStatus(status);

  const timeTBD = (event.timeValid ?? comp.timeValid) === false;

  return {
    id: event.id,
    league,
    status: gameStatus,
    scheduledAt: parseKickoff(event.date ?? comp.date ?? "", timeTBD),
    venue: transformVenue(comp.venue),
    homeTeam,
    awayTeam,
    broadcast: nonEmpty(comp.broadcasts?.[0]?.media?.shortName),
    clock: status?.displayClock,
    quarter: status?.period || undefined,
    week: hasWeeks(league) ? (event.week?.number ?? 0) : undefined,
    seasonYear: context.seasonYear ?? 0,
    conferenceGame: false,
    timeTBD,
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
 * Map a /teams/{id}/schedule payload, plus the preseason and postseason
 * responses fetched beside it.
 *
 * Each phase's events are stamped with **their own** season type, which is
 * what lets the Games tab split them into a card each: exhibition football
 * must never read as games that counted, and the phases arrive as three
 * separate requests precisely because ESPN won't return them together.
 *
 * `recordSummary`/`standingSummary` always describe ESPN's *current*
 * season — under a past season's games they'd be this year's numbers, so
 * they only survive when `season.year === requestedSeason.year`.
 */
export function transformTeamSchedule(
  regular: EspnScheduleResponse,
  league: League,
  extra: {
    preseason?: EspnScheduleEvent[];
    postseason?: EspnScheduleEvent[];
  } = {}
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
    }, league);
    team = mapped ?? undefined;
  }

  // ESPN stamps the NBA's and NHL's seasons with the year they *end* in;
  // our axis is always the opening year.
  const rawYear = regular.requestedSeason?.year;
  const year = rawYear !== undefined ? seasonYearFromEspn(league, rawYear) : undefined;
  const games = [
    ...(extra.preseason ?? []).map((event) =>
      transformScheduleEvent(event, league, { seasonYear: year, seasonType: 1 })
    ),
    ...(regular.events ?? []).map((event) =>
      transformScheduleEvent(event, league, { seasonYear: year, seasonType: 2 })
    ),
    ...(extra.postseason ?? []).map((event) =>
      transformScheduleEvent(event, league, { seasonYear: year, seasonType: 3 })
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
  summary: EspnGameSummaryResponse,
  league: League
): Game | null {
  const comp = summary.header?.competitions?.[0];
  if (!comp) return null;

  function side(homeAway: string): GameTeam | null {
    const competitor = comp?.competitors?.find(
      (c: EspnHeaderCompetitor) => c.homeAway === homeAway
    );
    if (!competitor?.team) return null;
    const team = transformTeam(competitor.team, league);
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
  const timeTBD = comp.timeValid === false;
  return {
    id: gameId,
    league,
    status,
    scheduledAt: parseKickoff(comp.date ?? "", timeTBD),
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
    week: undefined,
    seasonYear: 0,
    conferenceGame: comp.conferenceCompetition ?? false,
    timeTBD,
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

function transformLeaders(
  teamLeaders: EspnTeamLeaders[],
  awayTeamId: string | undefined,
  homeTeamId: string | undefined,
  league: League
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

  // The league's preferred categories are a preference, not a requirement:
  // where none of them match, fall back to whatever the payload actually
  // named. A category we didn't think of beats an empty card.
  const preferred = leagueSpec(league).leaderCategories;
  const categories: LeaderCategory[] = [];
  for (const category of preferred) {
    const away = leader(awayTeamId, category.name);
    const home = leader(homeTeamId, category.name);
    if (!away && !home) continue;
    categories.push({ id: category.name, label: category.label, away, home });
  }
  if (categories.length > 0) return categories;

  const named = new Map<string, string>();
  for (const teamLeader of teamLeaders) {
    for (const category of teamLeader.leaders ?? []) {
      if (category.name && !named.has(category.name)) {
        named.set(category.name, category.displayName ?? category.name);
      }
    }
  }
  for (const [name, label] of named) {
    const away = leader(awayTeamId, name);
    const home = leader(homeTeamId, name);
    if (!away && !home) continue;
    categories.push({ id: name, label, away, home });
  }
  return categories;
}

export function transformGameSummary(
  gameId: string,
  game: Game,
  summary: EspnGameSummaryResponse
): GameDetail {
  const league = game.league;
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
    // ESPN ships `grass: false` for arenas too, which rendered as
    // "Surface · Turf" on a hockey rink. The surface is only a fact about
    // the game where the game is played on one.
    venueSurface: !playsOnASurface(league)
      ? undefined
      : venue?.grass === undefined
        ? undefined
        : venue.grass
          ? "grass"
          : "turf",
    weatherCondition: summary.gameInfo?.weather?.displayValue,
    weatherTemperature:
      summary.gameInfo?.weather?.temperature != null
        ? Math.trunc(summary.gameInfo.weather.temperature)
        : undefined,
    leaders: transformLeaders(
      summary.leaders ?? [],
      awayTeamEspnId,
      homeTeamEspnId,
      league
    ),
    drives: drives.map(transformDrive),
    scoringPlays: (summary.scoringPlays ?? []).map(transformScoringPlay),
  };
}
