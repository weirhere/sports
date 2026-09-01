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
import { conferenceLogoUrl, conferenceName, orderedIds } from "@/lib/conferences";
import { liveStatusText } from "@/lib/format";
import { cn } from "@/lib/utils";
import type { Game, Scoreboard, Team } from "@/lib/types";

const CONFERENCE_CORPUS: ConferenceRef[] = orderedIds.map((id) => ({
  id,
  name: conferenceName(id),
}));

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
  const { conferences } = useTeamDirectory();
  const { favorites } = useFavoritesContext();
  const [query, setQuery] = useState("");
  const [games, setGames] = useState<Game[]>([]);

  // The CURRENT week's slate, fetched once on mount — no params, and no
  // refetching per keystroke (the filter is entirely client-side).
  useEffect(() => {
    let cancelled = false;
    fetch("/api/scoreboard")
      .then((res) => (res.ok ? (res.json() as Promise<Scoreboard>) : null))
      .then((board) => {
        if (!cancelled && board) setGames(board.games ?? []);
      })
      .catch(() => {
        // A missing slate just leaves the This Week section empty.
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
              {teamResults.map((team) => (
                <TeamResultRow key={team.id} team={team} />
              ))}
            </ResultSection>
          )}
          {conferenceResults.length > 0 && (
            <ResultSection title="Conferences">
              {conferenceResults.map((conference) => (
                <ConferenceResultRow
                  key={conference.id}
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
      href={`/team/${team.id}`}
      aria-label={label}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <TeamLogo espnId={team.espnId} teamName="" size="sm" />
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
      href={`/conference/${conference.id}`}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <ConferenceLogo src={conferenceLogoUrl(conference.id)} name="" />
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
      href={`/game/${game.id}`}
      className="flex items-center gap-3 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      <span className="flex shrink-0 items-center gap-1">
        <TeamLogo espnId={away.espnId} teamName="" size="sm" />
        <TeamLogo espnId={home.espnId} teamName="" size="sm" />
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
