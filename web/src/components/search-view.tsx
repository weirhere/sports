"use client";

// App-wide search — the web twin of the iOS `SearchScreen`
// (sports/Features/Search/SearchScreen.swift), rebuilt around the thumb on
// 2026-09-21: the title at the left, scope pills in place of section
// headings, one card per result, and the field at the **bottom**.
//
// Three corpora are already loaded (or one fetch away) and rank on the
// keystroke: every league's team directory, the conference registry, and
// the days around today. Two more arrive a beat later, beside them rather
// than instead of them: athletes from ESPN's search, and the matched teams'
// schedules for games past the loaded window.

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { X } from "lucide-react";
import { SearchField } from "@/components/search-field";
import { GameRow } from "@/components/game-row";
import {
  SearchScopePills,
  parseSearchScope,
  type SearchScope,
} from "@/components/search-scope-pills";
import {
  SEARCH_CARD_MIN_HEIGHT,
  SearchConferenceRow,
  SearchPlayerRow,
  SearchTeamRow,
  type SearchPlayer,
} from "@/components/search-result-rows";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useAthleteSearch } from "@/lib/hooks/use-athlete-search";
import { useTeamScheduleSearch } from "@/lib/hooks/use-team-schedule-search";
import { useRecentSearches } from "@/lib/hooks/use-recent-searches";
import { useFcsDirectory } from "@/lib/hooks/use-fcs-directory";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import {
  searchTeams,
  searchConferences,
  searchGames,
  type ConferenceRef,
} from "@/lib/search-ranking";
import { linkableAthletes } from "@/lib/athlete-search";
import { orderedAroundNow, unionGames } from "@/lib/search-games";
import { recentSearchId, type RecentSearch } from "@/lib/recent-searches";
import {
  childrenOf,
  conferenceName,
  leagueWideId,
  topLevelIds,
} from "@/lib/conferences";
import { LEAGUES } from "@/lib/leagues";
import { addDays, dayId, startOfDay } from "@/lib/day";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/page-header";
import type { Game, Scoreboard, Team } from "@/lib/types";
import { followKey } from "@/lib/refs";

/**
 * Every group anyone could search for, across all four leagues: a league's
 * top-level conferences plus the divisions beneath them, and college
 * football's FBS/FCS roots.
 *
 * It was college football's eleven conferences alone until 2026-09-09 — so
 * a search for "AFC East" or "Pacific" found nothing at all, in an app that
 * has shown four leagues since 2.0.
 */
const CONFERENCE_CORPUS: ConferenceRef[] = LEAGUES.flatMap((league) => {
  const ids = new Set<number>(topLevelIds(league));
  for (const id of topLevelIds(league)) {
    for (const child of childrenOf(id, league)) ids.add(child);
  }
  const wide = leagueWideId(league);
  if (wide !== undefined) ids.add(wide);
  return [...ids]
    .map((id) => ({ league, id, name: conferenceName(id, league) }))
    .filter((entry) => entry.name !== "Other");
});

type ResolvedRecent =
  | { entry: RecentSearch; kind: "team"; team: Team }
  | { entry: RecentSearch; kind: "conference"; conference: ConferenceRef }
  | { entry: RecentSearch; kind: "player"; player: SearchPlayer }
  | { entry: RecentSearch; kind: "game"; game: Game };

const RECENT_SCOPE: Record<ResolvedRecent["kind"], Exclude<SearchScope, "all">> = {
  team: "teams",
  conference: "conferences",
  player: "players",
  game: "games",
};

/** Which result kinds a scope shows: `all` shows everything, any other pill
 *  only its own. */
function shows(scope: SearchScope, kind: Exclude<SearchScope, "all">): boolean {
  return scope === "all" || scope === kind;
}

export function SearchView() {
  const router = useRouter();
  const searchParams = useSearchParams();
  // Every league's directory. It was college football's alone once, so the
  // tab could not find an NFL, NBA or NHL team at all.
  const { conferences } = useTeamDirectory(LEAGUES);
  const { favorites } = useFavoritesContext();
  const recents = useRecentSearches();

  // The query and the scope live in the URL as well as in state. That is
  // the web's version of iOS's two lifetimes (2026-09-21): a result tap
  // pushes a page, and Back must hand you the same results — the history
  // entry carries them. Reaching search from the tab bar is a fresh `/search`
  // with neither, which is iOS's "a tab switch resets the box".
  const [query, setQuery] = useState(() => searchParams.get("q") ?? "");
  const [scope, setScope] = useState<SearchScope>(() =>
    parseSearchScope(searchParams.get("scope"))
  );
  // Only a fresh box grabs the keyboard. Coming Back to a query, the list
  // is what you came back for.
  const [autoFocus] = useState(() => !searchParams.get("q"));
  const [games, setGames] = useState<Game[]>([]);

  useEffect(() => {
    const params = new URLSearchParams();
    if (query.length > 0) params.set("q", query);
    if (scope !== "all") params.set("scope", scope);
    const search = params.toString();
    // `replaceState`, not a router call: a keystroke is not a navigation,
    // and Next keeps `useSearchParams` in step with the native history API.
    window.history.replaceState(
      null,
      "",
      search.length > 0 ? `/search?${search}` : "/search"
    );
  }, [query, scope]);

  // The days around today, every league, fetched once on mount — no
  // refetching per keystroke, since the filter is entirely client-side.
  useEffect(() => {
    let cancelled = false;
    const today = startOfDay(new Date());
    const window = `start=${dayId(addDays(today, -1))}&end=${dayId(addDays(today, 5))}`;
    Promise.all(
      LEAGUES.map((league) =>
        fetch(`/api/scoreboard?league=${league}&${window}`)
          .then((res) => (res.ok ? (res.json() as Promise<Scoreboard>) : null))
          .catch(() => null)
      )
    ).then((boards) => {
      if (cancelled) return;
      // A league that missed costs its own games, not the section.
      setGames(boards.flatMap((board) => board?.games ?? []));
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const followedIds = useMemo(() => new Set(favorites), [favorites]);
  const trimmed = query.trim();

  // Follow boost ON here — results navigate, they don't toggle.
  const teamResults = useMemo(
    () => searchTeams(query, conferences, followedIds),
    [query, conferences, followedIds]
  );
  const conferenceResults = useMemo(
    () => searchConferences(query, CONFERENCE_CORPUS),
    [query]
  );
  const gameResults = useMemo(() => searchGames(query, games), [query, games]);

  const athleteSearch = useAthleteSearch(query);
  const fcs = useFcsDirectory();
  // Every club the app has a page for: the four leagues' directories plus
  // college football's FCS, which the shared directory leaves out.
  const clubDirectory = useMemo(() => [...conferences, ...fcs], [conferences, fcs]);
  const athletes = useMemo(
    () => linkableAthletes(athleteSearch.athletes, clubDirectory),
    [athleteSearch.athletes, clubDirectory]
  );

  // Driven by the matched teams rather than the raw string, so a request
  // only follows a search that already found something.
  const scheduleGames = useTeamScheduleSearch(teamResults);
  // The slate's matches plus the matched teams' remaining season, ordered
  // so the next kickoff leads.
  const visibleGames = useMemo(
    () => orderedAroundNow(unionGames(scheduleGames, gameResults)),
    [scheduleGames, gameResults]
  );

  const resolvedRecents = useMemo(
    () => resolveRecents(recents.entries, conferences, games),
    [recents.entries, conferences, games]
  );
  // Narrowed by the pills too. Without this the pills looked broken on the
  // screen people see first: every pill rendered the same list (iOS,
  // 2026-09-21).
  const scopedRecents = resolvedRecents.filter((recent) =>
    shows(scope, RECENT_SCOPE[recent.kind])
  );

  // True when the visible scope has nothing in it — not the same as the
  // query having no matches. Narrowed to Players, a query that found three
  // teams and no people is empty *here*, and saying so beats a blank page.
  const visibleResultsAreEmpty = !(
    (shows(scope, "teams") && teamResults.length > 0) ||
    (shows(scope, "conferences") && conferenceResults.length > 0) ||
    (shows(scope, "players") && athletes.length > 0) ||
    (shows(scope, "games") && visibleGames.length > 0)
  );

  const leave = () => {
    // The keyboard can cover the tab bar, so the field row carries its own
    // way out (iOS `onCancel`). Back where there is somewhere to go back
    // to; the front page when search was the first page of the visit.
    if (window.history.length > 1) router.back();
    else router.push("/");
  };

  const recordTeam = (team: Team) =>
    recents.record({ kind: "team", id: team.id, league: team.league });
  const recordConference = (conference: ConferenceRef) =>
    recents.record({
      kind: "conference",
      id: conference.id,
      league: conference.league,
    });
  const recordPlayer = (player: SearchPlayer) =>
    recents.record({
      kind: "player",
      id: player.athleteId,
      league: player.league,
      name: player.name,
      teamName: player.teamName,
      teamId: player.teamId,
      headshotUrl: player.headshotUrl,
    });
  const recordGame = (game: Game) =>
    recents.record({
      kind: "game",
      id: game.id,
      league: game.league,
      day: game.scheduledAt,
    });

  let content: React.ReactNode;
  if (trimmed.length === 0) {
    if (!recents.isLoaded) {
      // Storage hasn't been read yet: say nothing for the one frame rather
      // than flash the first-run sentence at someone who has recents.
      content = null;
    } else if (scopedRecents.length === 0) {
      // Kept for the one run where it is still true: before anything has
      // been opened there is nothing to hand back, and the corpus is worth
      // naming.
      content = (
        <CenteredMessage>
          Search teams, conferences, and this week&rsquo;s games
        </CenteredMessage>
      );
    } else {
      content = (
        <ul aria-label="Recent searches" className="flex flex-col gap-2">
          {scopedRecents.map((recent) => (
            <li
              key={recentSearchId(recent.entry)}
              className={cn("card-surface flex items-center", SEARCH_CARD_MIN_HEIGHT)}
            >
              <RecentRow
                recent={recent}
                onRecord={{
                  team: recordTeam,
                  conference: recordConference,
                  player: recordPlayer,
                  game: recordGame,
                }}
              />
              <DismissButton onClick={() => recents.remove(recent.entry)} />
            </li>
          ))}
        </ul>
      );
    }
  } else if (visibleResultsAreEmpty) {
    // Not "no results" while the network half is still out — that sentence
    // would be true for a beat and then wrong.
    content = (
      <CenteredMessage>
        {athleteSearch.isSearching
          ? "Searching…"
          : `No results for “${trimmed}”`}
      </CenteredMessage>
    );
  } else {
    // One card per result, not one card per section (iOS, 2026-09-21): a
    // game and a team are different shapes, and a shared card made them
    // read as one list of one kind of thing. The pills carry the taxonomy
    // the headings used to.
    content = (
      <div className="flex flex-col gap-2">
        {shows(scope, "teams") &&
          teamResults.map((team) => (
            // Keyed on the follow key, never the bare id: the Browns and
            // UAB are both ESPN team 5.
            <ResultCard key={followKey({ league: team.league, teamId: team.id })}>
              <SearchTeamRow team={team} onSelect={() => recordTeam(team)} />
            </ResultCard>
          ))}
        {shows(scope, "conferences") &&
          conferenceResults.map((conference) => (
            // Group 8 is the SEC here and the AFC in the NFL.
            <ResultCard key={`${conference.league}-${conference.id}`}>
              <SearchConferenceRow
                conference={conference}
                onSelect={() => recordConference(conference)}
              />
            </ResultCard>
          ))}
        {shows(scope, "players") &&
          athletes.map((player) => (
            <ResultCard key={`${player.league}-${player.athleteId}`}>
              <SearchPlayerRow player={player} onSelect={() => recordPlayer(player)} />
            </ResultCard>
          ))}
        {shows(scope, "games") && (
          <>
            {/* The scope, said out loud. These games come from the slate
                *and* the schedules of the teams this query matched — so a
                game between two teams you didn't type is not here, and a
                silent partial list is the one thing not to ship. */}
            {scheduleGames.length > 0 && (
              <p className="px-1 pt-1 type-meta text-text-secondary">
                Games for matching teams
              </p>
            )}
            {visibleGames.map((game) => (
              <ResultCard key={`${game.league}-${game.id}`}>
                <GameRow game={game} onSelect={() => recordGame(game)} />
              </ResultCard>
            ))}
          </>
        )}
      </div>
    );
  }

  return (
    // At least a screen tall, so the field sits at the foot of the viewport
    // even when the list above it is short: the nav bar (56px, 64px from
    // `sm`), <main>'s 12px top padding and — below `sm` — the fixed tab bar
    // (54px, measured) are what the field has to clear.
    <div className="flex min-h-[calc(100dvh-7.625rem-env(safe-area-inset-bottom))] flex-col sm:min-h-[calc(100dvh-4.75rem)]">
      {/* The root tabs' one masthead (iOS `PageHeader`, 2026-09-21). */}
      <PageHeader title="Search" />
      <SearchScopePills selection={scope} onSelect={setScope} />
      <div className="flex-1 pb-3 pt-1">{content}</div>

      {/* The field rides the bottom (iOS, 2026-09-21): at the top it sat at
          the farthest point on screen from the thumb typing into it. iOS
          lifts it on the keyboard with `safeAreaInset`; a browser has no
          keyboard inset to ride, so here it is a sticky footer bar — pinned
          to the viewport's foot above the tab bar while the list scrolls
          under it. Below `sm` it rides on top of the fixed tab bar. */}
      <div className="sticky bottom-[calc(3.375rem+env(safe-area-inset-bottom))] z-40 -mx-4 flex items-center gap-3 border-t border-divider bg-bg-primary px-4 py-2 sm:bottom-0">
        <SearchField
          value={query}
          onChange={setQuery}
          placeholder="Teams, players, conferences, games"
          autoFocus={autoFocus}
          className="flex-1"
        />
        {/* Phone widths only: the way out exists because the keyboard can
            cover the tab bar, and from `sm` there is no tab bar to cover. */}
        <button
          type="button"
          onClick={leave}
          className="shrink-0 type-chip text-text-primary sm:hidden"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

/**
 * Recents, resolved against today's data. Persisted entries carry `(id,
 * league)` only, so each row is drawn from the live directory, registry or
 * slate rather than a snapshot — except a player, whose entry *is* the
 * snapshot. An entry that resolves to nothing (a league whose directory
 * hasn't loaded, a game whose day isn't in the slate) is skipped for this
 * render, never deleted: a recent must not evaporate because the page was
 * opened offline.
 */
function resolveRecents(
  entries: readonly RecentSearch[],
  conferences: readonly { teams: Team[] }[],
  games: readonly Game[]
): ResolvedRecent[] {
  const teams = conferences.flatMap((conference) => conference.teams);
  return entries.flatMap((entry): ResolvedRecent[] => {
    switch (entry.kind) {
      case "team": {
        const team = teams.find(
          (t) => t.league === entry.league && t.id === entry.id
        );
        return team ? [{ entry, kind: "team", team }] : [];
      }
      case "conference": {
        const conference = CONFERENCE_CORPUS.find(
          (c) => c.league === entry.league && c.id === entry.id
        );
        return conference ? [{ entry, kind: "conference", conference }] : [];
      }
      case "player":
        return [
          {
            entry,
            kind: "player",
            player: {
              athleteId: entry.id,
              league: entry.league,
              name: entry.name,
              teamId: entry.teamId,
              teamName: entry.teamName,
              headshotUrl: entry.headshotUrl,
            },
          },
        ];
      case "game": {
        const game = games.find(
          (g) => g.league === entry.league && g.id === entry.id
        );
        return game ? [{ entry, kind: "game", game }] : [];
      }
    }
  });
}

function RecentRow({
  recent,
  onRecord,
}: {
  recent: ResolvedRecent;
  onRecord: {
    team: (team: Team) => void;
    conference: (conference: ConferenceRef) => void;
    player: (player: SearchPlayer) => void;
    game: (game: Game) => void;
  };
}) {
  switch (recent.kind) {
    case "team":
      return (
        <SearchTeamRow team={recent.team} onSelect={() => onRecord.team(recent.team)} />
      );
    case "conference":
      return (
        <SearchConferenceRow
          conference={recent.conference}
          onSelect={() => onRecord.conference(recent.conference)}
        />
      );
    case "player":
      return (
        <SearchPlayerRow
          player={recent.player}
          onSelect={() => onRecord.player(recent.player)}
        />
      );
    case "game":
      return (
        <div className="min-w-0 flex-1">
          <GameRow game={recent.game} onSelect={() => onRecord.game(recent.game)} />
        </div>
      );
  }
}

/**
 * Clears one row from the list. Trailing and outside the row's own link, so
 * a tap here can't be read as opening the thing you meant to forget.
 */
function DismissButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Remove from recent searches"
      className="mr-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-text-secondary/60 transition-colors hover:text-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <X aria-hidden="true" className="h-4 w-4" />
    </button>
  );
}

function ResultCard({ children }: { children: React.ReactNode }) {
  return (
    <div className={cn("card-surface flex", SEARCH_CARD_MIN_HEIGHT)}>
      {/* The row stretches to the card's floor rather than centring inside
          a taller box, so the whole card is the link's hit area. */}
      <div className="flex min-w-0 flex-1 [&>a]:flex-1">{children}</div>
    </div>
  );
}

function CenteredMessage({ children }: { children: React.ReactNode }) {
  return (
    <p className="px-6 py-20 text-center type-team-name text-text-secondary">
      {children}
    </p>
  );
}
