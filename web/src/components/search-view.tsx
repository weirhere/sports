"use client";

import { useState, useMemo, useEffect, useRef } from "react";
import Link from "next/link";
import Image from "next/image";
import { Search, User } from "lucide-react";
import { SearchInput } from "@/components/search-input";
import { cn } from "@/lib/utils";
import { MOCK_TEAMS } from "@/lib/mock/teams";
import { ALL_CONFERENCES } from "@/config/conferences";
import { TeamLogo } from "@/components/team-logo";
import type { Player, Game, GameStatus, Team, Conference } from "@/lib/types";

type Category = "all" | "teams" | "conferences" | "players" | "games";

const CATEGORIES: { value: Category; label: string }[] = [
  { value: "all", label: "All" },
  { value: "teams", label: "Teams" },
  { value: "conferences", label: "Conferences" },
  { value: "players", label: "Players" },
  { value: "games", label: "Games" },
];

function isLive(status: GameStatus) {
  return status === "in_progress" || status === "halftime" || status === "end_period";
}

function getGameLabel(game: Game): string {
  if (game.status === "complete") return "Final";
  if (game.status === "halftime") return "Halftime";
  if (isLive(game.status)) {
    const q = game.quarter && game.quarter > 4 ? "OT" : `Q${game.quarter}`;
    return `${q} ${game.clock || ""}`.trim();
  }
  return new Date(game.scheduledAt).toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

/* ------------------------------------------------------------------ */
/*  Result row components                                              */
/* ------------------------------------------------------------------ */

function TeamResult({ team }: { team: Team }) {
  return (
    <Link
      href={`/team/${team.id}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      <TeamLogo espnId={team.espnId} teamName={team.school} size="sm" />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{team.school}</p>
        <p className="text-xs text-muted-foreground">{team.conferenceName}</p>
      </div>
    </Link>
  );
}

function ConferenceResult({ conf }: { conf: Conference }) {
  return (
    <Link
      href={`/conferences/${conf.id}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      <div className="flex h-6 w-6 items-center justify-center rounded bg-muted text-[10px] font-bold text-muted-foreground">
        {conf.shortName.slice(0, 3)}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{conf.shortName}</p>
        <p className="text-xs text-muted-foreground">{conf.name}</p>
      </div>
    </Link>
  );
}

function PlayerResult({ player }: { player: Player }) {
  return (
    <Link
      href={`/team/${player.teamId}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      {player.headshotUrl ? (
        <Image
          src={player.headshotUrl}
          alt={player.displayName}
          width={24}
          height={24}
          className="rounded-full"
          unoptimized
        />
      ) : (
        <div className="flex h-6 w-6 items-center justify-center rounded-full bg-muted">
          <User className="h-3.5 w-3.5 text-muted-foreground" />
        </div>
      )}
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">
          {player.displayName}
          {player.jersey && (
            <span className="ml-1.5 text-xs font-normal text-muted-foreground">
              #{player.jersey}
            </span>
          )}
        </p>
        <p className="text-xs text-muted-foreground">
          {player.position} · {player.teamName}
        </p>
      </div>
    </Link>
  );
}

function GameResult({ game }: { game: Game }) {
  const live = isLive(game.status);

  return (
    <Link
      href={`/game/${game.id}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      <div className="flex items-center gap-1.5">
        <TeamLogo espnId={game.awayTeam.team.espnId} teamName={game.awayTeam.team.school} size="sm" />
        <span className="text-xs text-muted-foreground">@</span>
        <TeamLogo espnId={game.homeTeam.team.espnId} teamName={game.homeTeam.team.school} size="sm" />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">
          {game.awayTeam.team.abbreviation} vs {game.homeTeam.team.abbreviation}
        </p>
        <p className={cn(
          "text-xs",
          live ? "font-medium text-live" : "text-muted-foreground"
        )}>
          {game.status !== "scheduled" && (
            <span>
              {game.awayTeam.score} - {game.homeTeam.score} · {" "}
            </span>
          )}
          {getGameLabel(game)}
        </p>
      </div>
    </Link>
  );
}

/* ------------------------------------------------------------------ */
/*  Section wrapper                                                    */
/* ------------------------------------------------------------------ */

function ResultSection({
  title,
  children,
  count,
}: {
  title: string;
  children: React.ReactNode;
  count: number;
}) {
  if (count === 0) return null;
  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-card">
      <div className="px-4 py-2.5 bg-muted/50">
        <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {title}
        </span>
      </div>
      <div className="border-t">{children}</div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Main component                                                     */
/* ------------------------------------------------------------------ */

export function SearchView() {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<Category>("all");
  const [players, setPlayers] = useState<Player[]>([]);
  const [games, setGames] = useState<Game[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);

  // Fetch players and games on mount
  useEffect(() => {
    fetch("/api/players")
      .then((r) => r.json())
      .then((data) => setPlayers(data))
      .catch(() => {});

    fetch("/api/schedule")
      .then((r) => r.json())
      .then((data) => setGames(data.games ?? []))
      .catch(() => {});
  }, []);

  // Auto-focus input
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const q = query.trim().toLowerCase();
  const isSearching = q.length > 0;

  // Filter results
  const teamResults = useMemo(() => {
    if (!isSearching) return [];
    return MOCK_TEAMS.filter(
      (t) =>
        t.school.toLowerCase().includes(q) ||
        t.name.toLowerCase().includes(q) ||
        t.abbreviation.toLowerCase().includes(q) ||
        t.conferenceName.toLowerCase().includes(q)
    );
  }, [q, isSearching]);

  const confResults = useMemo(() => {
    if (!isSearching) return [];
    return ALL_CONFERENCES.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.shortName.toLowerCase().includes(q)
    );
  }, [q, isSearching]);

  const playerResults = useMemo(() => {
    if (!isSearching) return [];
    return players.filter(
      (p) =>
        p.displayName.toLowerCase().includes(q) ||
        p.firstName.toLowerCase().includes(q) ||
        p.lastName.toLowerCase().includes(q) ||
        p.position.toLowerCase().includes(q) ||
        p.teamName.toLowerCase().includes(q)
    );
  }, [q, isSearching, players]);

  const gameResults = useMemo(() => {
    if (!isSearching) return [];
    return games.filter(
      (g) =>
        g.homeTeam.team.school.toLowerCase().includes(q) ||
        g.homeTeam.team.abbreviation.toLowerCase().includes(q) ||
        g.awayTeam.team.school.toLowerCase().includes(q) ||
        g.awayTeam.team.abbreviation.toLowerCase().includes(q) ||
        g.venue.name.toLowerCase().includes(q) ||
        g.venue.city.toLowerCase().includes(q)
    );
  }, [q, isSearching, games]);

  const showTeams = category === "all" || category === "teams";
  const showConfs = category === "all" || category === "conferences";
  const showPlayers = category === "all" || category === "players";
  const showGames = category === "all" || category === "games";

  const totalResults =
    (showTeams ? teamResults.length : 0) +
    (showConfs ? confResults.length : 0) +
    (showPlayers ? playerResults.length : 0) +
    (showGames ? gameResults.length : 0);

  return (
    <div className="space-y-4">
      {/* Search input */}
      <SearchInput
        ref={inputRef}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onClear={() => setQuery("")}
        placeholder="Search teams, conferences, players, games..."
      />

      {/* Category tabs */}
      <div className="flex gap-2 overflow-x-auto">
        {CATEGORIES.map((cat) => (
          <button
            key={cat.value}
            type="button"
            onClick={() => setCategory(cat.value)}
            className={cn(
              "shrink-0 rounded-full border px-3 py-1 text-xs font-medium transition-colors",
              category === cat.value
                ? "border-foreground bg-foreground text-background"
                : "border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground"
            )}
          >
            {cat.label}
          </button>
        ))}
      </div>

      {/* Results */}
      {isSearching ? (
        totalResults > 0 ? (
          <div className="space-y-3">
            {showTeams && teamResults.length > 0 && (
              <ResultSection title="Teams" count={teamResults.length}>
                {teamResults.map((team, i) => (
                  <div key={team.id}>
                    {i > 0 && <div className="mx-4 border-t" />}
                    <TeamResult team={team} />
                  </div>
                ))}
              </ResultSection>
            )}

            {showConfs && confResults.length > 0 && (
              <ResultSection title="Conferences" count={confResults.length}>
                {confResults.map((conf, i) => (
                  <div key={conf.id}>
                    {i > 0 && <div className="mx-4 border-t" />}
                    <ConferenceResult conf={conf} />
                  </div>
                ))}
              </ResultSection>
            )}

            {showPlayers && playerResults.length > 0 && (
              <ResultSection title="Players" count={playerResults.length}>
                {playerResults.map((player, i) => (
                  <div key={player.id}>
                    {i > 0 && <div className="mx-4 border-t" />}
                    <PlayerResult player={player} />
                  </div>
                ))}
              </ResultSection>
            )}

            {showGames && gameResults.length > 0 && (
              <ResultSection title="Games" count={gameResults.length}>
                {gameResults.map((game, i) => (
                  <div key={game.id}>
                    {i > 0 && <div className="mx-4 border-t" />}
                    <GameResult game={game} />
                  </div>
                ))}
              </ResultSection>
            )}
          </div>
        ) : (
          <p className="py-12 text-center text-sm text-muted-foreground">
            No results for &ldquo;{query.trim()}&rdquo;
          </p>
        )
      ) : (
        <div className="flex flex-col items-center justify-center gap-2 py-16 text-center">
          <Search className="h-10 w-10 text-muted-foreground/30" />
          <p className="text-sm text-muted-foreground">
            Search for teams, conferences, players, and games
          </p>
        </div>
      )}
    </div>
  );
}
