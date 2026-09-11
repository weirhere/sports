"use client";

// The hub's contents (iOS `TablesScreen`): Following first, then one
// accordion per league.
//
// Each league answers the question its own way. College football leads with
// the Top 25 row — the poll one tap down, so the conferences aren't buried
// under 25 rank rows — then FBS's eleven conferences and FCS's fourteen,
// in one card. The pro leagues have no poll at all, so they lead with their
// own whole-league table and then list **divisions**: a division is the
// race a team is actually in, where a conference is a seeding pool for a
// bracket (iOS, 2026-09-09).
//
// FCS is inside College Football's card, not beside it: the accordions are
// leagues, and FCS is a division of one, so a card of its own read as a
// third league. Its conferences sort below the eleven FBS ones on the tier
// rule that already orders the list.

import { useMemo } from "react";
import Link from "next/link";
import { ChevronDown, Star } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import {
  conferenceLogoUrl,
  conferenceName,
  divisionGroupId,
  isDivisionRoot,
  collegeDivision,
} from "@/lib/conferences";
import {
  divisionsIn,
  findTable,
  foldingDivisions,
  followableTables,
  isFollowable,
  isLeagueWide,
  leaderOf,
  leaderRecord,
  leagueTable,
  tableRef,
} from "@/lib/standings-tables";
import {
  LEAGUES,
  displayName,
  leagueLogoUrl,
  type League,
} from "@/lib/leagues";
import type { ConferenceStandingsGroup, Poll } from "@/lib/types";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useUIState } from "@/lib/hooks/use-ui-state";
import { conferenceToken } from "@/lib/refs";
import { conferencePath } from "@/lib/routes";
import { orderedTables } from "@/lib/followed-tables";
import { FollowedTablesList } from "@/components/followed-tables-list";
import { cn } from "@/lib/utils";

interface LeaguesHubProps {
  /** The polls, filtered and in picker order (AP first when present). */
  polls: Poll[];
  /** Each league's tables — divisional for the pro leagues. */
  standings: Record<League, ConferenceStandingsGroup[]>;
  /** College football's other division, fetched and failing separately. */
  fcsStandings: ConferenceStandingsGroup[];
  hasAnyPoll: boolean;
}

/** A row in a league's accordion: the poll, or one table. */
export type HubRow =
  | { kind: "poll"; league: League; polls: Poll[] }
  | { kind: "table"; table: ConferenceStandingsGroup };

export function LeaguesHub({
  polls,
  standings,
  fcsStandings,
}: LeaguesHubProps) {
  const uiState = useUIState();
  const { favoriteConferences, favoritePolls } = useFavoritesContext();

  /**
   * Divisions folded into their conference: the Sun Belt, not
   * "Sun Belt - East" and "Sun Belt - West"; the AFC, not its four.
   *
   * College football's two divisions fold together here — the fetches stay
   * separate, the list doesn't. Folding the union in one pass is what sorts
   * FBS above FCS, since the fold re-applies the tier rule across
   * everything it's handed.
   *
   * For the pro leagues this is a *derivation*, not a fetch: their request
   * is the divisional one, and folding it back up is what gives the league
   * row something to merge.
   */
  const conferencesIn = useMemo(() => {
    const cache = {} as Record<League, ConferenceStandingsGroup[]>;
    for (const league of LEAGUES) {
      const fetched = [
        ...(standings[league] ?? []),
        ...(league === "cfb" ? fcsStandings : []),
      ];
      cache[league] = foldingDivisions(fetched);
    }
    return cache;
  }, [standings, fcsStandings]);

  /**
   * College football's list, each division led by its own root row: FBS
   * above the eleven, FCS above the fourteen.
   *
   * The roots are placeholder tables — a name and an id, no entries. They
   * exist to be rows and destinations; the standings behind them are
   * fetched by the page they open, which is the only place a 136-team list
   * of conferences is worth assembling.
   */
  const collegeTables = useMemo((): ConferenceStandingsGroup[] => {
    const all = conferencesIn.cfb;
    const rows: ConferenceStandingsGroup[] = [];
    for (const division of ["FBS", "FCS"] as const) {
      const members = all.filter(
        (table) => collegeDivision(Number(table.id), "cfb") === division
      );
      if (members.length === 0) continue;
      const id = divisionGroupId(division);
      rows.push({
        id: String(id),
        league: "cfb",
        name: conferenceName(id, "cfb"),
        entries: [],
      });
      rows.push(...members);
    }
    // Anything the division tables don't claim — an unknown id — keeps its
    // place at the end rather than vanishing.
    const claimed = new Set(rows.map((table) => table.id));
    return [...rows, ...all.filter((table) => !claimed.has(table.id))];
  }, [conferencesIn]);

  /**
   * What a league's accordion holds, league-wide row first: the whole thing
   * above its parts.
   */
  const tablesIn = useMemo(() => {
    const cache = {} as Record<League, ConferenceStandingsGroup[]>;
    for (const league of LEAGUES) {
      if (league === "cfb") {
        cache[league] = collegeTables;
        continue;
      }
      const wide = leagueTable(conferencesIn[league], league);
      cache[league] = [
        ...(wide ? [wide] : []),
        ...divisionsIn(standings[league] ?? [], league),
      ];
    }
    return cache;
  }, [collegeTables, conferencesIn, standings]);

  const rowsIn = useMemo(() => {
    const cache = {} as Record<League, HubRow[]>;
    for (const league of LEAGUES) {
      const rows: HubRow[] = [];
      // College football is the only league that polls.
      if (league === "cfb" && polls.length > 0) {
        rows.push({ kind: "poll", league, polls });
      }
      rows.push(
        ...tablesIn[league].map(
          (table): HubRow => ({ kind: "table", table })
        )
      );
      cache[league] = rows;
    }
    return cache;
  }, [polls, tablesIn]);

  /**
   * Every table someone could be following, including the conference rows
   * the accordion no longer lists. A conference follow made before the hub
   * showed divisions still has a card in Following and still hoists its
   * section on Scores.
   */
  const loadedTables = useMemo(
    () =>
      LEAGUES.flatMap((league) =>
        followableTables(tablesIn[league], conferencesIn[league])
      ),
    [tablesIn, conferencesIn]
  );

  const followed = useMemo(
    () =>
      orderedTables({
        followedConferenceTokens: favoriteConferences,
        followedPollLeagues: favoritePolls,
        order: uiState.tableOrder,
      }),
    [favoriteConferences, favoritePolls, uiState.tableOrder]
  );

  /**
   * The Following section's cards, resolved against what actually loaded: a
   * followed table whose fetch came back empty has no card here, exactly as
   * it has no accordion below. Nothing errors over a missing one.
   */
  const followedRows = useMemo(
    () =>
      followed.filter((table) =>
        table.kind === "poll"
          ? polls.length > 0
          : findTable(loadedTables, table.ref) !== undefined
      ),
    [followed, loadedTables, polls]
  );

  const leagues = LEAGUES.filter((league) => rowsIn[league].length > 0);

  if (leagues.length === 0) {
    return (
      <p className="py-20 text-center type-team-name text-text-secondary">
        No tables right now
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {/* See TeamsList: the bar names the app, not the page. */}
      <h1 className="sr-only">Leagues</h1>
      {followedRows.length > 0 && (
        <>
          <SectionHeading title="Following" />
          <FollowedTablesList
            tables={followedRows}
            order={uiState.tableOrder}
            onReorder={uiState.setTableOrder}
            resolve={(table) =>
              table.kind === "poll"
                ? undefined
                : findTable(loadedTables, table.ref)
            }
            polls={polls}
          />
        </>
      )}

      {/* The complete list. Followed rows repeat inside their league —
          sections stay complete, never deduplicated. */}
      {followedRows.length > 0 && <SectionHeading title="Leagues" />}
      {leagues.map((league) => (
        <LeagueAccordion
          key={league}
          league={league}
          rows={rowsIn[league]}
          isExpanded={!uiState.isCollapsed(`league-${league}`)}
          onToggle={() => uiState.toggleSection(`league-${league}`)}
        />
      ))}
    </div>
  );
}

function SectionHeading({ title }: { title: string }) {
  return (
    <h2 className="px-1 pt-1 type-team-name-em text-text-primary">{title}</h2>
  );
}

/** One league's card: a header that collapses, and its tables inside. */
function LeagueAccordion({
  league,
  rows,
  isExpanded,
  onToggle,
}: {
  league: League;
  rows: HubRow[];
  isExpanded: boolean;
  onToggle: () => void;
}) {
  const reducedMotion = useReducedMotion();
  return (
    <section className="card-surface">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={isExpanded}
        aria-label={`${displayName(league)}, ${rows.length} ${
          rows.length === 1 ? "table" : "tables"
        }`}
        className="flex min-h-12 w-full items-center gap-3 bg-bg-header px-4 py-2.5 text-left transition-colors hover:bg-bg-elevated/60"
      >
        <ConferenceLogo src={leagueLogoUrl(league)} name="" />
        <span className="type-section-header text-text-primary">
          {displayName(league)}
        </span>
        <span className="ml-auto type-meta text-text-secondary">
          {rows.length}
        </span>
        <ChevronDown
          aria-hidden="true"
          className={cn(
            "h-4 w-4 text-text-secondary transition-transform",
            isExpanded && "rotate-180"
          )}
        />
      </button>

      <AnimatePresence initial={false}>
        {isExpanded && (
          <motion.div
            initial={{ height: 0 }}
            animate={{ height: "auto" }}
            exit={{ height: 0 }}
            transition={
              reducedMotion
                ? { duration: 0 }
                : { duration: 0.25, ease: [0.4, 0, 0.2, 1] }
            }
            className="overflow-clip"
          >
            {rows.map((row, index) => (
              <div key={rowKey(row)}>
                {index > 0 && <div className="ml-4 border-t border-divider" />}
                {row.kind === "poll" ? (
                  <Top25Row polls={row.polls} league={row.league} />
                ) : (
                  <TableRow table={row.table} />
                )}
              </div>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </section>
  );
}

function rowKey(row: HubRow): string {
  return row.kind === "poll" ? `poll-${row.league}` : `table-${row.table.id}`;
}

/**
 * The poll's row — the same shape as a table row, leading its league.
 *
 * It wears **college football's mark, not a trophy** (iOS, 2026-09-06):
 * "Top 25" never said whose, which is fine while one league polls and
 * confusing the moment a second one does.
 */
export function Top25Row({
  polls,
  league,
}: {
  polls: Poll[];
  league: League;
}) {
  const { isFavoritePoll, toggleFavoritePoll } = useFavoritesContext();
  // "#1 Ohio State" from the first displayed poll. The row doesn't track
  // the picker choice — it's a teaser, not the poll.
  const top = polls[0]?.ranks[0];
  const followed = isFavoritePoll(league);

  return (
    <div className="flex min-h-12 items-center gap-3 pr-2">
      <Link
        href="/rankings/poll"
        className="flex min-w-0 flex-1 items-center gap-3 self-stretch px-4 py-[7px] transition-colors hover:bg-bg-header"
        aria-label={top ? `Top 25, number 1 ${top.team.school}` : "Top 25"}
      >
        <ConferenceLogo src={leagueLogoUrl(league)} name="" />
        <span className="shrink-0 type-team-name text-text-primary">
          Top 25
        </span>
        {top && (
          <span className="truncate type-meta text-text-secondary">
            #1 {top.team.school}
          </span>
        )}
      </Link>
      <FollowStar
        followed={followed}
        name="Top 25"
        onToggle={() => toggleFavoritePoll(league)}
      />
    </div>
  );
}

/**
 * One table: mark, name, leader teaser, follow star. The row navigates to
 * that table's page; the star doesn't.
 */
function TableRow({ table }: { table: ConferenceStandingsGroup }) {
  const { isFavoriteConference, toggleFavoriteConference } =
    useFavoritesContext();
  const ref = tableRef(table);
  const token = ref ? conferenceToken(ref) : undefined;
  const followed = token !== undefined && isFavoriteConference(token);

  const leader = leaderOf(table);
  const record = leader ? leaderRecord(leader) : undefined;

  /**
   * A **whole-league row shows no teaser at all** (iOS, 2026-09-09). Its
   * "leader" is only the best record in the sport, which is not what a
   * league row is asked — and the number would be an *in-group* record on
   * a row spanning every group.
   *
   * A college-football division root shows none either: FBS's "leader" is
   * whichever conference table happened to sort first.
   */
  const teasable =
    !isLeagueWide(table) && !isDivisionRoot(Number(table.id), table.league);
  const teaser =
    teasable && leader && record
      ? `${leader.team.school} · ${record}`
      : undefined;

  const spokenRecord = record?.replaceAll("-", " and ");
  const rowLabel = teaser
    ? `${table.name}, led by ${leader!.team.school} at ${spokenRecord}`
    : table.name;

  return (
    <div className="flex min-h-12 items-center gap-3 pr-2">
      <Link
        href={ref ? conferencePath(ref) : "#"}
        className="flex min-w-0 flex-1 items-center gap-3 self-stretch px-4 py-[7px] transition-colors hover:bg-bg-header"
        aria-label={rowLabel}
      >
        <ConferenceLogo
          src={ref ? conferenceLogoUrl(ref.id, ref.league) : undefined}
          name=""
        />
        <span className="shrink-0 type-team-name text-text-primary">
          {table.name}
        </span>
        {teaser && (
          <span className="truncate type-meta text-text-secondary">
            {teaser}
          </span>
        )}
      </Link>
      {token !== undefined && isFollowable(table) && (
        <FollowStar
          followed={followed}
          name={table.name}
          onToggle={() => toggleFavoriteConference(token)}
        />
      )}
    </div>
  );
}

export function FollowStar({
  followed,
  name,
  onToggle,
}: {
  followed: boolean;
  name: string;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-label={followed ? `Unfollow ${name}` : `Follow ${name}`}
      aria-pressed={followed}
      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-text-secondary transition-colors hover:text-text-primary"
    >
      <Star
        aria-hidden="true"
        className={cn("h-4 w-4", followed && "fill-current text-text-primary")}
      />
    </button>
  );
}
