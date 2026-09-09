// One followable table — a poll, or a conference/division/whole-league
// group. A port of `FollowedTable` (StatSideShared/Models/FollowedTable.swift).
//
// The two follow sets answer the same question in two shapes: "which
// standings-shaped thing do I care about". Since iOS 2026-09-06 the Scores
// screen hoists them together, so they need one identity, one token and one
// order.
//
// Deliberately *not* a team follow. A team follow puts games in the Scores
// Following section; a table follow moves that table's section up the page
// instead. Following is "my teams" — a conference is a slate, and a slate the
// size of the Big Ten would bury the three games you actually care about.

import {
  conferenceChain,
  conferenceLogoUrl,
  conferenceName,
  tier,
  tierRank,
} from "./conferences";
import { LEAGUES, leagueLogoUrl, type League } from "./leagues";
import {
  conferenceToken,
  parseConferenceToken,
  sameConference,
  type ConferenceRef,
} from "./refs";
import type { Game } from "./types";

export type FollowedTable =
  | { kind: "poll"; league: League }
  | { kind: "conference"; ref: ConferenceRef };

/** The persistence + drag token: `"poll-cfb"` / `"conf-cfb:8"`. */
export function tableToken(table: FollowedTable): string {
  return table.kind === "poll"
    ? `poll-${table.league}`
    : `conf-${conferenceToken(table.ref)}`;
}

export function parseTableToken(token: string): FollowedTable | undefined {
  if (token.startsWith("poll-")) {
    const league = token.slice("poll-".length);
    return (LEAGUES as readonly string[]).includes(league)
      ? { kind: "poll", league: league as League }
      : undefined;
  }
  if (token.startsWith("conf-")) {
    const ref = parseConferenceToken(token.slice("conf-".length));
    return ref ? { kind: "conference", ref } : undefined;
  }
  return undefined;
}

export function tableLeague(table: FollowedTable): League {
  return table.kind === "poll" ? table.league : table.ref.league;
}

/** What the Scores section header calls it. */
export function tableName(table: FollowedTable): string {
  return table.kind === "poll"
    ? "Top 25"
    : conferenceName(table.ref.id, table.ref.league);
}

/**
 * The mark beside that header.
 *
 * A poll wears its **league's** mark, not a trophy (iOS, 2026-09-06):
 * "Top 25" never said whose, which is fine while one league polls and wrong
 * the moment a second one does.
 */
export function tableLogoUrl(table: FollowedTable): string | undefined {
  return table.kind === "poll"
    ? leagueLogoUrl(table.league)
    : conferenceLogoUrl(table.ref.id, table.ref.league);
}

export function sameTable(a: FollowedTable, b: FollowedTable): boolean {
  if (a.kind !== b.kind) return false;
  return a.kind === "poll"
    ? a.league === (b as typeof a).league
    : sameConference(a.ref, (b as { ref: ConferenceRef }).ref);
}

function involvesRankedTeam(game: Game): boolean {
  return (
    game.homeTeam.ranking !== undefined || game.awayTeam.ranking !== undefined
  );
}

/**
 * Whether this table claims a game.
 *
 * The conference case walks the group chain, so a followed AFC matches a
 * Bills game even though ESPN's NFL scoreboard only ever hands us the
 * *division* id — and a followed NFL (group 9) matches all 32 teams.
 */
export function tableMatches(table: FollowedTable, game: Game): boolean {
  if (table.kind === "poll") {
    return game.league === table.league && involvesRankedTeam(game);
  }
  return [game.homeTeam, game.awayTeam].some((side) => {
    const id = Number(side.team.conferenceId);
    if (!Number.isFinite(id)) return false;
    return conferenceChain({ league: game.league, id }).some((link) =>
      sameConference(link, table.ref)
    );
  });
}

/**
 * The order a followed set falls into before anyone drags anything: polls
 * first (a league's headline answer), then its groups widest first,
 * alphabetically inside a tier — the Leagues hub's own order.
 */
export function compareTablesByDefault(
  lhs: FollowedTable,
  rhs: FollowedTable
): number {
  const [ll, rl] = [tableLeague(lhs), tableLeague(rhs)];
  if (ll !== rl) return LEAGUES.indexOf(ll) - LEAGUES.indexOf(rl);
  if (lhs.kind !== rhs.kind) return lhs.kind === "poll" ? -1 : 1;
  if (lhs.kind === "poll") return 0;
  const rhsRef = (rhs as { ref: ConferenceRef }).ref;
  const lt = tierRank(tier(lhs.ref.id, lhs.ref.league));
  const rt = tierRank(tier(rhsRef.id, rhsRef.league));
  if (lt !== rt) return lt - rt;
  return conferenceName(lhs.ref.id, lhs.ref.league) <
    conferenceName(rhsRef.id, rhsRef.league)
    ? -1
    : 1;
}

/**
 * The followed tables in the order they lead the Scores page, from the two
 * stored sets plus the user's own drag order.
 *
 * A set saved before dragging existed falls back to the default order, so
 * nothing needs migrating. An entry in `order` that is no longer followed is
 * ignored rather than resurrected.
 */
export function orderedTables(options: {
  followedConferenceTokens: readonly string[];
  followedPollLeagues: readonly string[];
  order?: readonly string[];
}): FollowedTable[] {
  const tables: FollowedTable[] = [];
  for (const token of options.followedConferenceTokens) {
    const ref = parseConferenceToken(token);
    if (ref) tables.push({ kind: "conference", ref });
  }
  for (const league of options.followedPollLeagues) {
    if ((LEAGUES as readonly string[]).includes(league)) {
      tables.push({ kind: "poll", league: league as League });
    }
  }

  const order = options.order ?? [];
  const rank = new Map(order.map((token, index) => [token, index]));
  return tables.sort((lhs, rhs) => {
    const [lr, rr] = [rank.get(tableToken(lhs)), rank.get(tableToken(rhs))];
    // A dragged table outranks one that has never been dragged, which is
    // what lets a new follow land at the end.
    if (lr !== undefined && rr !== undefined) return lr - rr;
    if (lr !== undefined) return -1;
    if (rr !== undefined) return 1;
    return compareTablesByDefault(lhs, rhs);
  });
}
