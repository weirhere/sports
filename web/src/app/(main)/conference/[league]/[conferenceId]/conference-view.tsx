"use client";

// The ConferencePage client shell — Standings leads (the iOS 2026-08-31
// order), Games carries the season's full slate one card per week with the
// postseason last. Season flips navigate `?year=` so the server refetch is
// the per-year cache.

import { useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { conferenceLogoUrl } from "@/lib/conferences";
import { seasonYear, seasonYears, type League } from "@/lib/leagues";
import type { ConferenceStandingsGroup, Game } from "@/lib/types";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { FollowPill } from "@/components/follow-pill";
import { CardHeader } from "@/components/card-header";
import { StandingsList } from "@/components/standings-list";
import { StandingsScopeChip } from "@/components/standings-scope-chip";
import { divisionShortName, tablesAtScope } from "@/lib/standings-tables";
import {
  defaultScope,
  scopesFor,
  type StandingsScope,
} from "@/lib/standings-scope";
import { gamePath } from "@/lib/routes";
import { GameMatchupRow, gameRowLabel } from "@/components/next-game-card";
import { ConferenceLogo } from "@/components/theme/conference-logo";

// Ordered — Standings first and the entry default (FotMob's Leagues order).
const TABS: HeroTab[] = [
  { id: "standings", label: "Standings" },
  { id: "games", label: "Games" },
];

interface WeekGroup {
  id: string;
  title: string;
  games: Game[];
}

/**
 * The season slate's grouping — iOS `ConferenceSlate.groups`: regular-season
 * weeks ascending, then a dateless bucket, then the postseason — whose week
 * numbers restart at 1 and must never land a title game in "Week 1". Games
 * sort chronologically within a group.
 */
export function groupSeasonSlate(games: Game[]): WeekGroup[] {
  const time = (game: Game) => {
    const parsed = Date.parse(game.scheduledAt);
    return Number.isNaN(parsed) ? Number.POSITIVE_INFINITY : parsed;
  };
  const sorted = [...games].sort((a, b) => time(a) - time(b));

  const regular = new Map<number, Game[]>();
  const postseason: Game[] = [];
  const undated: Game[] = [];
  for (const game of sorted) {
    const week = game.week;
    if (game.seasonType === 3) {
      postseason.push(game);
    } else if (week !== undefined && week >= 1) {
      const bucket = regular.get(week);
      if (bucket) bucket.push(game);
      else regular.set(week, [game]);
    } else {
      // A league with no weeks at all (the NBA and NHL ship `week: null` on
      // every event) files its whole slate here rather than under a Week 1
      // that doesn't exist.
      undated.push(game);
    }
  }

  const groups: WeekGroup[] = [...regular.keys()]
    .sort((a, b) => a - b)
    .map((week) => ({
      id: `week-${week}`,
      title: `Week ${week}`,
      games: regular.get(week) ?? [],
    }));
  if (undated.length > 0) {
    groups.push({ id: "week-other", title: "More games", games: undated });
  }
  if (postseason.length > 0) {
    groups.push({ id: "week-postseason", title: "Postseason", games: postseason });
  }
  return groups;
}

interface ConferenceViewProps {
  league: League;
  conferenceId: number;
  name: string;
  /**
   * Every table the league returned, at whatever depth — the scope chip is
   * a *view* of one fetch, so a page holds them all and shows a slice.
   * Null = the fetch failed.
   */
  allTables: ConferenceStandingsGroup[] | null;
  /** The season's full conference slate; null = the fetch failed. */
  games: Game[] | null;
  displayYear: number;
  /** Anchor this team's row — standings pushes from other pages. */
  highlightTeamId?: string;
}

export function ConferenceView({
  league,
  conferenceId,
  name,
  allTables,
  games,
  displayYear,
  highlightTeamId,
}: ConferenceViewProps) {
  const router = useRouter();
  const [tab, setTab] = useState("standings");

  const conferenceRef = useMemo(
    () => ({ league, id: conferenceId }),
    [league, conferenceId]
  );

  // Which scopes this page offers comes from where it sits in the league's
  // own hierarchy: the league page all three, a conference page the two
  // below it, and anything that nests nothing — every college-football
  // conference — none, which is what hides the control.
  const scopes = useMemo(() => scopesFor(conferenceRef), [conferenceRef]);
  const baseScope = useMemo(
    () => defaultScope(scopes, "conference"),
    [scopes]
  );
  const [scopeChoice, setScopeChoice] = useState<StandingsScope | undefined>();
  const scope = scopeChoice ?? baseScope ?? "conference";
  const setScope = (next: StandingsScope) => setScopeChoice(next);

  const scopedTables = useMemo(
    () => (allTables ? tablesAtScope(allTables, conferenceRef, scope) : []),
    [allTables, conferenceRef, scope]
  );

  const weekGroups = useMemo(() => groupSeasonSlate(games ?? []), [games]);
  // The hero count sums every division, however the tables are sliced.
  const teamCount = useMemo(() => {
    if (!allTables) return 0;
    const own = tablesAtScope(allTables, conferenceRef, "conference");
    return own.reduce((total, table) => total + table.entries.length, 0);
  }, [allTables, conferenceRef]);
  const logoUrl = conferenceLogoUrl(conferenceId, league);

  const selectYear = (year: number) => {
    const query = year === seasonYear(league) ? "" : `?year=${year}`;
    router.push(`/conference/${league}/${conferenceId}${query}`);
  };


  const retryRow = (message: string) => (
    <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
      <p className="type-team-name text-text-secondary">{message}</p>
      <button
        type="button"
        onClick={() => router.refresh()}
        className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
      >
        Retry
      </button>
    </section>
  );

  return (
    <div>
      <HeroHeader
        logo={
          logoUrl ? (
            // The conference mark keeps the logo-backing disc — navy marks
            // (Big Ten, ACC) vanish on black, and ESPN serves no dark
            // conference variants. The disc is chrome, not color.
            <span className="inline-flex items-center justify-center rounded-full bg-logo-backing p-1.5">
              <Image
                src={logoUrl}
                alt=""
                width={44}
                height={44}
                className="h-11 w-11 object-contain"
                unoptimized
              />
            </span>
          ) : (
            <ConferenceLogo src={undefined} name="" />
          )
        }
        title={name}
        subtitle={
          teamCount > 0 ? (
            <span className="type-chip-em text-text-secondary">
              {teamCount} teams
            </span>
          ) : undefined
        }
        trailing={
          <>
            {/* The season scopes every tab, so it sits beside the page's
                identity rather than above one pane's cards (iOS,
                2026-09-05). */}
            <SeasonMenuChip
              value={displayYear}
              years={seasonYears(league)}
              onSelect={selectYear}
            />
            <FollowPill
              league={league}
              id={String(conferenceId)}
              kind="conference"
              name={name}
            />
          </>
        }
        tabs={<HeroTabBar tabs={TABS} selected={tab} onSelect={setTab} />}
        controls={
          tab === "standings" ? (
            <StandingsScopeChip
              scopes={scopes}
              selection={scope}
              base={baseScope ?? scope}
              onSelect={setScope}
            />
          ) : undefined
        }
      />

      <div
        role="tabpanel"
        id={`panel-${tab}`}
        aria-labelledby={`tab-${tab}`}
        className="flex flex-col gap-2 py-2"
      >
        {tab === "standings" &&
          (allTables === null ? (
            retryRow("Couldn't load standings.")
          ) : scopedTables.length === 0 ? (
            <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
              Standings TBA
            </section>
          ) : (
            // One card per table. A divisional conference keeps its
            // divisions **separate** (iOS, 2026-09-05): merging them
            // numbered teams 1 through 14 across two divisions ESPN never
            // ranked against each other, which is exactly the tiebreaker
            // guesswork the standings contract forbids, printed as a place
            // column.
            scopedTables.map((table) => (
              <section key={table.id} className="card-surface pb-1">
                {scopedTables.length > 1 && (
                  <CardHeader title={divisionShortName(table, name)} />
                )}
                <StandingsList
                  league={league}
                  entries={table.entries}
                  conferenceId={Number(table.id)}
                  year={displayYear}
                  // The top-two cut is suppressed whenever the tables are
                  // divisions: in a divisional format the division winners
                  // meet, so a per-division footnote would claim the wrong
                  // thing.
                  showsCut={scopedTables.length === 1 && !table.spansDivisions}
                  highlightTeamId={highlightTeamId}
                />
              </section>
            ))
          ))}

        {tab === "games" && (
          <>
            {games === null ? (
              retryRow("Couldn't load the schedule.")
            ) : weekGroups.length === 0 ? (
              <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
                Schedule TBA
              </section>
            ) : (
              weekGroups.map((group) => (
                <section key={group.id} className="card-surface pb-1">
                  <CardHeader title={group.title} />
                  {group.games.map((game, index) => (
                    <div key={game.id}>
                      {index > 0 && (
                        <div className="ml-4 border-t border-divider" />
                      )}
                      <Link
                        href={gamePath(game)}
                        aria-label={gameRowLabel(game)}
                        className="block transition-colors hover:bg-bg-header"
                        suppressHydrationWarning
                      >
                        <GameMatchupRow game={game} />
                      </Link>
                    </div>
                  ))}
                </section>
              ))
            )}
          </>
        )}
      </div>
    </div>
  );
}
