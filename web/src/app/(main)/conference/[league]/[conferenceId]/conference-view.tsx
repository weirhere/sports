"use client";

// The ConferencePage client shell — Standings leads (the iOS 2026-08-31
// order), Games carries the season's slate under the control row every
// Games tab shares. Season flips navigate `?year=` so the server refetch is
// the per-year cache.

import { useMemo, useState } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { conferenceLogoUrl } from "@/lib/conferences";
import { hasWeeks, seasonYear, seasonYears, type League } from "@/lib/leagues";
import type { ConferenceStandingsGroup, Game, Team } from "@/lib/types";
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
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { ConferenceGamesList } from "@/components/conference-games-list";
import {
  SlateControlRow,
  toggledGrouping,
} from "@/components/slate-control-row";
import { gamesForTeam, type SlateGrouping } from "@/lib/conference-slate";
import { PostseasonSection } from "@/components/postseason-section";
import {
  defaultRound,
  postseasonExhibition,
  postseasonRounds,
} from "@/lib/postseason";

// Ordered — Standings first and the entry default (FotMob's Leagues order).
const BASE_TABS: HeroTab[] = [
  { id: "standings", label: "Standings" },
  { id: "games", label: "Games" },
];

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

  // Weeks is the season's own clock and the default where a league has
  // them; the NBA and NHL send `week: null` on every event, so their pane
  // opens grouped by day rather than under one unheaded card.
  const [grouping, setGrouping] = useState<SlateGrouping>(
    hasWeeks(league) ? "week" : "day"
  );
  const [teamChoice, setTeamChoice] = useState<string | undefined>();
  const [roundChoice, setRoundChoice] = useState<string | undefined>();

  // The filter's roster: the conference's own members, from the season's
  // standings — the one list that says who *belongs* rather than who showed
  // up, since the slate also carries every non-conference opponent. Where
  // ESPN ships no standings (its Sun Belt hole, an offseason table) the
  // slate's teams stand in, because a filter with no names is no filter.
  const filterableTeams = useMemo<Team[]>(() => {
    const members = allTables
      ? tablesAtScope(allTables, conferenceRef, "conference")
          .flatMap((table) => table.entries)
          .map((entry) => entry.team)
      : [];
    if (members.length > 0) {
      return [...members].sort((a, b) => a.school.localeCompare(b.school));
    }
    const seen = new Set<string>();
    return (games ?? [])
      .flatMap((game) => [game.awayTeam.team, game.homeTeam.team])
      .filter((team) => !seen.has(team.id) && seen.add(team.id))
      .sort((a, b) => a.school.localeCompare(b.school));
  }, [allTables, conferenceRef, games]);

  // The pick, honored only while this season's conference actually has that
  // team. A stale pick reads as "All teams" rather than emptying the pane
  // with a name that means nothing here — which is what lets the choice
  // survive a season flip instead of being reset by one.
  const activeTeam = filterableTeams.find((team) => team.id === teamChoice);
  const filteredGames = useMemo(
    () => gamesForTeam(games ?? [], activeTeam?.id),
    [games, activeTeam?.id]
  );

  // The hero count sums every division, however the tables are sliced.
  const teamCount = useMemo(() => {
    if (!allTables) return 0;
    const own = tablesAtScope(allTables, conferenceRef, "conference");
    return own.reduce((total, table) => total + table.entries.length, 0);
  }, [allTables, conferenceRef]);
  const logoUrl = conferenceLogoUrl(conferenceId, league);

  // The postseason is already in hand: the Games tab fetches the whole
  // season, so splitting the bracket out costs no request. A tab that would
  // open on "no games" is worse than no tab, so it appears only where this
  // season's slate actually has a playoff — and never for the NBA or NHL,
  // whose best-of-seven series this single-elimination bracket can't model.
  const rounds = useMemo(
    () => postseasonRounds(games ?? [], league),
    [games, league]
  );
  const exhibition = useMemo(
    () => postseasonExhibition(games ?? [], league),
    [games, league]
  );
  // A picked round survives a season switch only where the new season has one
  // by that name — the season chip's own disproof rule.
  const activeRound =
    roundChoice && rounds.some((round) => round.name === roundChoice)
      ? roundChoice
      : defaultRound(rounds);

  const tabs: HeroTab[] =
    rounds.length > 0
      ? [...BASE_TABS, { id: "postseason", label: "Postseason" }]
      : BASE_TABS;
  const activeTab = tabs.some((entry) => entry.id === tab) ? tab : "standings";

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
        tabs={<HeroTabBar tabs={tabs} selected={activeTab} onSelect={setTab} />}
        controls={
          activeTab === "postseason" ? (
            // The Postseason tab brings its own control — the round chips,
            // inside the pane where the bracket is. A second row of chrome
            // above them was just noise.
            undefined
          ) : activeTab === "standings" ? (
            <StandingsScopeChip
              scopes={scopes}
              selection={scope}
              base={baseScope ?? scope}
              onSelect={setScope}
            />
          ) : (
            <SlateControlRow
              grouping={grouping}
              onToggle={(value) =>
                setGrouping((current) => toggledGrouping(current, value))
              }
              teams={filterableTeams}
              teamSelection={activeTeam?.id}
              onSelectTeam={setTeamChoice}
              hasWeeks={hasWeeks(league)}
            />
          )
        }
      />

      <div
        role="tabpanel"
        id={`panel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
        className="flex flex-col gap-2 py-2"
      >
        {activeTab === "standings" &&
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

        {activeTab === "games" && (
          <>
            {games === null ? (
              retryRow("Couldn't load the schedule.")
            ) : filteredGames.length > 0 ? (
              <ConferenceGamesList games={filteredGames} grouping={grouping} />
            ) : activeTeam && games.length > 0 ? (
              // The narrowed-empty state, Scores' rule (iOS, 2026-08-29):
              // name what's hiding the games and offer them back, so a
              // filtered pane never reads as a missing schedule.
              <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
                <p className="type-team-name text-text-secondary">
                  No {displayYear} games for {activeTeam.school}
                </p>
                <button
                  type="button"
                  onClick={() => setTeamChoice(undefined)}
                  className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
                >
                  Show all teams
                </button>
              </section>
            ) : (
              <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
                Schedule TBA
              </section>
            )}
          </>
        )}

        {activeTab === "postseason" && (
          <PostseasonSection
            rounds={rounds}
            exhibition={exhibition}
            selection={activeRound}
            onSelectRound={setRoundChoice}
          />
        )}
      </div>
    </div>
  );
}
