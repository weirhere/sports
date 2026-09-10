"use client";

// The detail header (iOS GameDetailScreen.header): equal thirds — away
// team link, center column, home team link. Once the game has scores the
// matchup's number is the page's headline: one large centered "7 – 33"
// between the logos (FotMob's full-time layout), status demoted beneath
// it. Pre-game shows NO scores — no 0–0.

import Link from "next/link";
import type { Game, GameTeam } from "@/lib/types";
import { teamPath } from "@/lib/routes";
import { LiveDot } from "@/components/theme/live-dot";
import { cn } from "@/lib/utils";
import { TeamMark } from "./team-mark";
import {
  isLiveStatus,
  kickoffHero,
  showsScores,
  statusLine,
  statusSubline,
} from "./game-status";

export function GameHeader({ game }: { game: Game }) {
  const live = isLiveStatus(game.status);
  const scores = showsScores(game);
  const awayScore = game.awayTeam.score;
  const homeScore = game.homeTeam.score;
  const scoreLineVisible = scores && awayScore !== null && homeScore !== null;
  const line = statusLine(game);
  const subline = statusSubline(game);
  // A pre-game page's one question is *when*, so the kickoff takes the slot
  // a played game's score takes (iOS, 2026-09-09). "Wed, Sep 9 at 8:20 PM"
  // set in the quietest type on the page answered it in a whisper while the
  // space between the logos sat empty.
  const kickoff = kickoffHero(game);

  return (
    <header className="card-surface">
      <div className="flex items-start gap-4 px-4 py-5">
        <TeamSide side={game.awayTeam} scores={scores} />

        <div
          className={cn(
            "flex min-w-0 flex-none flex-col items-center gap-1",
            !scoreLineVisible && !kickoff && "pt-3"
          )}
        >
          {live && <LiveDot />}
          {scoreLineVisible && (
            <p
              className={cn(
                "whitespace-nowrap",
                live ? "type-score-hero-live" : "type-score-hero"
              )}
            >
              {live && <span className="sr-only">Live, </span>}
              <span
                className={
                  game.awayTeam.isWinner === false
                    ? "text-text-secondary"
                    : "text-text-primary"
                }
              >
                {awayScore}
              </span>
              <span className="text-text-secondary"> – </span>
              <span
                className={
                  game.homeTeam.isWinner === false
                    ? "text-text-secondary"
                    : "text-text-primary"
                }
              >
                {homeScore}
              </span>
            </p>
          )}
          {kickoff ? (
            <>
              <p className="whitespace-nowrap type-kickoff-hero text-text-primary">
                {kickoff.time}
              </p>
              {kickoff.date && (
                <p className="text-center type-team-name text-text-secondary">
                  {kickoff.date}
                </p>
              )}
              {/* The network gets its own third line: the kickoff split left
                  it without the second line it used to ride in on. */}
              {game.broadcast && (
                <p className="text-center type-meta text-text-secondary">
                  {game.broadcast}
                </p>
              )}
              <span className="sr-only">
                {[kickoff.date, kickoff.time].filter(Boolean).join(", ")}
              </span>
            </>
          ) : (
            <>
              <p
                className={cn(
                  "text-center type-meta-em tnum",
                  scores ? "text-text-secondary" : "text-text-primary"
                )}
              >
                {line}
              </p>
              {subline && (
                <p className="text-center type-meta text-text-secondary">
                  {subline}
                </p>
              )}
            </>
          )}
        </div>

        <TeamSide side={game.homeTeam} scores={scores} />
      </div>
    </header>
  );
}

/**
 * One side: logo, rank + name, record — a link to the team page. Spoken as
 * "team + score" once scores exist.
 */
function TeamSide({ side, scores }: { side: GameTeam; scores: boolean }) {
  const label =
    scores && side.score !== null
      ? `${side.team.school} ${side.score}`
      : side.team.school;

  return (
    <Link
      // League-qualified, always. ESPN's team ids collide across leagues —
      // id 2 is Auburn *and* the Bills — so a bare `/team/2` resolves
      // through the legacy fallback and lands a Bills link on Auburn. The
      // header knows the league; it must not throw it away.
      href={teamPath(side.team)}
      aria-label={label}
      className="flex min-w-0 flex-1 flex-col items-center gap-1 text-center transition-opacity hover:opacity-80"
    >
      <TeamMark
        logoUrl={side.team.logoUrl}
        alt=""
        size={44}
        className="h-11 w-11 object-contain"
      />
      {/* Reserved two-line height so a wrapping name ("Arkansas-Pine
          Bluff") doesn't push its record below the other side's. */}
      <p className="min-h-[45px] w-full">
        {side.ranking && (
          <span className="type-row-meta text-text-secondary">
            {side.ranking}{" "}
          </span>
        )}
        <span
          className={cn(
            "text-text-primary",
            side.isWinner === true ? "type-team-name-em" : "type-team-name"
          )}
        >
          {side.team.school}
        </span>
      </p>
      {side.record && (
        <span className="type-meta tnum text-text-secondary">
          {side.record}
        </span>
      )}
    </Link>
  );
}
