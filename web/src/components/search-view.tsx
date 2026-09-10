"use client";

// App-wide search — the web twin of the iOS `SearchScreen`. The corpus is
// whatever's already loaded (or one fetch away): the FBS team directory,
// the registry conferences, and the current week's games. Results are
// ranked client-side by `search-ranking`, so typing costs zero requests.

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { TeamLogo } from "@/components/team-logo";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { SearchField } from "@/components/search-field";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import {
  searchTeams,
  searchConferences,
  searchGames,
  type ConferenceRef,
} from "@/lib/search-ranking";
import {
  childrenOf,
  conferenceLogoUrl,
  conferenceName,
  leagueWideId,
  topLevelIds,
} from "@/lib/conferences";
import { LEAGUES } from "@/lib/leagues";
import { addDays, dayId, startOfDay } from "@/lib/day";
import { liveStatusText } from "@/lib/format";
import { cn } from "@/lib/utils";
import type { Game, Scoreboard, Team } from "@/lib/types";
import { conferencePath, gamePath, teamPath } from "@/lib/routes";
import { followKey } from "@/lib/refs";

/**
 * Every group anyone could search for, across all four leagues: a league's
 * top-level conferences plus the divisions beneath them, and college
 * football's FBS/FCS roots.
 *
 * It was college football's eleven conferences alone until now — so a search
 * for "AFC East" or "Pacific" found nothing at all, in an app that has shown
 * four leagues since 2.0.
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

function isLive(game: Game): boolean {
  return (
    game.status === "in_progress" ||
    game.status === "halftime" ||
    game.status === "end_period"
  );
}

/** The compact status text for a search result row. */
function gameStatusShort(game: Game): string {
  if (game.status === "complete") return "Final";
  if (game.status === "postponed") return "Postponed";
  if (game.status === "cancelled") return "Cancelled";
  if (game.status === "delayed") return "Delayed";
  if (isLive(game)) {
    return (
      liveStatusText({
        livePhase:
          game.status === "halftime"
            ? "halftime"
            : game.status === "end_period"
              ? "endOfPeriod"
              : (game.livePhase ?? "playing"),
        quarter: game.quarter,
        clock: game.clock,
        detail: game.statusDetail,
      }) ?? "Live"
    );
  }
  const date = new Date(game.scheduledAt);
  if (Number.isNaN(date.getTime())) return "TBD";
  const day = date.toLocaleDateString("en-US", { weekday: "short" });
  if (game.timeTBD) return `${day} TBD`;
  const time = date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
  return `${day} ${time}`;
}

export function SearchView() {
  // Every league's directory. It was college football's alone, so the tab
  // could not find an NFL, NBA or NHL team at all — the league axis landed
  // in 2.0 and search's corpus never widened with it.
  const { conferences } = useTeamDirectory(LEAGUES);
  const { favorites } = useFavoritesContext();
  const [query, setQuery] = useState("");
  const [games, setGames] = useState<Game[]>([]);

  // The days around today, every league, fetched once on mount — no
  // refetching per keystroke, since the filter is entirely client-side.
  //
  // The old call was a bare `/api/scoreboard` with no league at all, which
  // the route answers with a **400** — so this section has been empty since
  // the league axis landed.
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

  const isEmpty =
    teamResults.length === 0 &&
    conferenceResults.length === 0 &&
    gameResults.length === 0;

  return (
    <div className="space-y-3">
      <h1 className="sr-only">Search</h1>
      <SearchField
        value={query}
        onChange={setQuery}
        placeholder="Teams, conferences, games"
        autoFocus
      />

      {trimmed.length === 0 ? (
        <p className="px-6 py-20 text-center type-team-name text-text-secondary">
          Search teams, conferences, and this week&rsquo;s games
        </p>
      ) : isEmpty ? (
        <p className="px-6 py-20 text-center type-team-name text-text-secondary">
          No matches
        </p>
      ) : (
        <div className="space-y-2">
          {teamResults.length > 0 && (
            <ResultSection title="Teams">
              {/* Keyed on the follow key, never the bare id: the Browns and
                  UAB are both ESPN team 5, so `team.id` hands two different
                  teams one React identity and the row keeps the previous
                  team's state as the query changes — a Bills row wearing
                  Auburn's mark. */}
              {teamResults.map((team) => (
                <TeamResultRow
                  key={followKey({ league: team.league, teamId: team.id })}
                  team={team}
                />
              ))}
            </ResultSection>
          )}
          {conferenceResults.length > 0 && (
            <ResultSection title="Conferences">
              {conferenceResults.map((conference) => (
                <ConferenceResultRow
                  // Group 8 is the SEC here and the AFC in the NFL.
                  key={`${conference.league}-${conference.id}`}
                  conference={conference}
                />
              ))}
            </ResultSection>
          )}
          {gameResults.length > 0 && (
            <ResultSection title="This Week">
              {gameResults.map((game) => (
                <GameResultRow key={game.id} game={game} />
              ))}
            </ResultSection>
          )}
        </div>
      )}
    </div>
  );
}

function ResultSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="card-surface pb-1">
      <h2 className="bg-bg-header px-4 py-2.5 type-section-header text-text-primary">
        {title}
      </h2>
      {children}
    </section>
  );
}

function TeamResultRow({ team }: { team: Team }) {
  const label = [team.school, team.name].filter(Boolean).join(" ");
  return (
    <Link
      href={teamPath(team)}
      aria-label={label}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <TeamLogo team={team} teamName="" size="sm" />
      <span className="truncate type-row-name-em text-text-primary">
        {team.school}
      </span>
      {team.name && (
        <span className="truncate type-row-name text-text-secondary">
          {team.name}
        </span>
      )}
    </Link>
  );
}

function ConferenceResultRow({ conference }: { conference: ConferenceRef }) {
  return (
    <Link
      href={conferencePath(conference)}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <ConferenceLogo
        src={conferenceLogoUrl(conference.id, conference.league)}
        name=""
      />
      <span className="type-row-name-em text-text-primary">
        {conference.name}
      </span>
    </Link>
  );
}

/** A compact matchup line: names + short status (not the Scores GameRow). */
function GameResultRow({ game }: { game: Game }) {
  const live = isLive(game);
  const away = game.awayTeam.team;
  const home = game.homeTeam.team;
  return (
    <Link
      // League-qualified: a summary fetched from the wrong league's base
      // URL 404s, so the event id never travels alone.
      href={gamePath(game)}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <span className="flex shrink-0 items-center gap-1">
        <TeamLogo team={away} teamName="" size="sm" />
        <TeamLogo team={home} teamName="" size="sm" />
      </span>
      <span className="min-w-0 flex-1 truncate type-row-name text-text-primary">
        {away.school} at {home.school}
      </span>
      <span
        className={cn(
          "shrink-0 tnum",
          live
            ? "type-row-name-em text-live"
            : "type-row-meta-medium text-text-secondary"
        )}
      >
        {gameStatusShort(game)}
      </span>
    </Link>
  );
}
