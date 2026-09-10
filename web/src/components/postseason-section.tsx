"use client";

// The Postseason tab: a bracket, drawn — the web twin of iOS
// `PostseasonSection` (Features/Conference/PostseasonSection.swift).
//
// Deliberately not the card-list format every other pane uses. A round of
// games is a list; a bracket is a *shape*, and the shape is the information —
// which two games feed the next one. So the games become individual match
// cards in two columns, the selected round beside the one it feeds, joined by
// hairline connectors.
//
// **The connectors are earned, never assumed.** A line is drawn only where a
// completed game's winner actually appears in a later game. ESPN publishes no
// bracket tree, and guessing who *would* play whom is the same tiebreaker
// invention the standings contract forbids. So an unplayed round shows its
// cards with no lines yet, and the bracket wires itself up as games finish. A
// wrong line is far worse than a missing one.

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import {
  BRACKET_CARD_GAP,
  BRACKET_CARD_HEIGHT,
  bracketHeight,
  bracketPairing,
  bracketPlacements,
  sourceHeight,
  sourceTops,
  type BracketPairing,
  type PostseasonRound,
} from "@/lib/postseason";
import type { Game, GameTeam, Team } from "@/lib/types";
import { gameState, otherStatusText } from "@/lib/game-state";
import { liveStatusText } from "@/lib/format";
import { gamePath } from "@/lib/routes";
import { TeamLogo } from "@/components/team-logo";
import { useSwipe } from "@/lib/hooks/use-swipe";
import { cn } from "@/lib/utils";

/** Both columns fit the pane, so the bracket never scrolls sideways itself —
 *  which is what frees the horizontal axis for the round swipe. */
const COLUMN_GAP = 28;

export function PostseasonSection({
  rounds,
  exhibition,
  selection,
  onSelectRound,
}: {
  rounds: PostseasonRound[];
  /** The fixture that sits outside the bracket — the NFL's Pro Bowl. */
  exhibition?: PostseasonRound;
  selection?: string;
  onSelectRound: (name: string) => void;
}) {
  const activeIndex = Math.max(
    0,
    rounds.findIndex((round) => round.name === selection)
  );
  const active = rounds[activeIndex];
  const next = rounds[activeIndex + 1];

  const step = (delta: number) => {
    const target = rounds[activeIndex + delta];
    if (target) onSelectRound(target.name);
  };
  // A gesture-only accelerator, like the tab swipe it sits inside: every
  // round stays one chip tap away, so nothing is swipe-gated. The ends are a
  // quiet no-op rather than a bounce into nothing.
  const { ref: swipeRef } = useSwipe<HTMLDivElement>({
    onSwipeLeft: () => step(1),
    onSwipeRight: () => step(-1),
  });

  if (!active) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No postseason games
      </section>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <RoundChips
        rounds={rounds}
        selected={active.name}
        onSelect={onSelectRound}
      />
      <div ref={swipeRef} className="touch-pan-y">
        <BracketPane round={active} next={next} />
      </div>
      {/* The Pro Bowl, under the final rather than between the rounds — the
          bronze-final treatment. Only on the last round's screen, because
          that is where a fixture outside the bracket belongs: after it, not
          inside it. */}
      {activeIndex === rounds.length - 1 && exhibition && (
        <div className="flex flex-col gap-1 pt-2">
          <p className="type-row-meta-medium text-text-secondary">
            {exhibition.name}
          </p>
          <div className="flex flex-col gap-2">
            {exhibition.games.map((game) => (
              <div key={game.id} className="w-[calc(50%-14px)]" style={{ height: BRACKET_CARD_HEIGHT }}>
                <MatchCard game={game} />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * A scroller, unlike the Games tab's control row: five rounds of "Conference
 * Championships" never fit a phone's width, and both references scroll theirs.
 */
function RoundChips({
  rounds,
  selected,
  onSelect,
}: {
  rounds: PostseasonRound[];
  selected: string;
  onSelect: (name: string) => void;
}) {
  return (
    <div className="-mx-4 overflow-x-auto px-4 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      <div className="flex w-max gap-2 py-1">
        {rounds.map((round) => {
          const isOn = round.name === selected;
          return (
            <button
              key={round.name}
              type="button"
              onClick={() => onSelect(round.name)}
              aria-pressed={isOn}
              className={cn(
                "inline-flex min-h-9 items-center whitespace-nowrap rounded-full px-3 py-1.5 type-chip transition-colors",
                isOn
                  ? "bg-text-primary text-bg-primary"
                  : "bg-bg-elevated text-text-primary hover:bg-divider"
              )}
            >
              {round.name}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function BracketPane({
  round,
  next,
}: {
  round: PostseasonRound;
  next?: PostseasonRound;
}) {
  const [width, setWidth] = useState(0);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = boxRef.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => {
      setWidth(entry.contentRect.width);
    });
    observer.observe(el);
    setWidth(el.getBoundingClientRect().width);
    return () => observer.disconnect();
  }, []);

  const pairing = next ? bracketPairing(round.games, next.games) : undefined;

  return (
    <div ref={boxRef}>
      {pairing ? (
        <Paired pairing={pairing} paneWidth={width} />
      ) : (
        // Nothing connects these two rounds yet, so they are two lists side
        // by side and say so — no lines, no implied order.
        <div className="flex items-start" style={{ gap: COLUMN_GAP }}>
          <PlainColumn games={round.games} />
          {/* The column holds its half whether or not there is a round to
              its right — a final that stretched the pane's whole width
              would read as a different kind of card. */}
          {next ? <PlainColumn games={next.games} /> : <div className="flex-1" />}
        </div>
      )}
    </div>
  );
}

/**
 * The drawn bracket: sources stacked on the left in bracket order, each
 * next-round game placed level with the middle of its own sources. That
 * placement is the whole point — a game sitting opposite what feeds it needs
 * no line crossing the column to reach it.
 */
function Paired({
  pairing,
  paneWidth,
}: {
  pairing: BracketPairing;
  paneWidth: number;
}) {
  const tops = sourceTops(pairing.sources);
  const placements = bracketPlacements(pairing, tops);
  const height = bracketHeight(pairing, tops, placements);
  const columnWidth = Math.max(0, (paneWidth - COLUMN_GAP) / 2);

  return (
    <div className="relative">
      <div className="flex items-start" style={{ gap: COLUMN_GAP }}>
        <div className="relative flex-1" style={{ height }}>
          {pairing.sources.map((source, index) => (
            <div
              key={source.id}
              className="absolute inset-x-0"
              style={{ top: tops[index], height: sourceHeight(source) }}
            >
              {source.kind === "bye" ? (
                <ByeCard team={source.team} />
              ) : (
                <MatchCard game={source.game} />
              )}
            </div>
          ))}
        </div>
        <div className="relative flex-1" style={{ height }}>
          {placements.map(({ game, top }) => (
            <div
              key={game.id}
              className="absolute inset-x-0"
              style={{ top, height: BRACKET_CARD_HEIGHT }}
            >
              <MatchCard game={game} />
            </div>
          ))}
        </div>
      </div>
      {columnWidth > 0 && (
        <Connectors
          pairing={pairing}
          tops={tops}
          placements={placements}
          columnWidth={columnWidth}
          width={paneWidth}
          height={height}
        />
      )}
    </div>
  );
}

/**
 * One hairline per source, drawn between the slots the layout actually chose:
 * horizontal out, a rounded turn, vertical, another turn, horizontal in — a
 * bracket's own line. A feeder already level with its target draws straight
 * through, since a curve with nothing to curve around reads as a wobble.
 */
function Connectors({
  pairing,
  tops,
  placements,
  columnWidth,
  width,
  height,
}: {
  pairing: BracketPairing;
  tops: number[];
  placements: { game: Game; top: number }[];
  columnWidth: number;
  width: number;
  height: number;
}) {
  const startX = columnWidth;
  const endX = columnWidth + COLUMN_GAP;
  const midX = startX + COLUMN_GAP / 2;
  const segments: string[] = [];

  for (const link of pairing.links) {
    const placement = placements.find((p) => p.game.id === link.game.id);
    if (!placement) continue;
    const endY = placement.top + BRACKET_CARD_HEIGHT / 2;
    for (const index of link.sourceIndices) {
      if (index < 0 || index >= tops.length) continue;
      const startY = tops[index] + sourceHeight(pairing.sources[index]) / 2;
      segments.push(elbow(startX, startY, endX, endY, midX));
    }
  }

  return (
    <svg
      aria-hidden="true"
      className="pointer-events-none absolute left-0 top-0 text-divider"
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      fill="none"
    >
      {segments.map((d, i) => (
        <path
          key={i}
          d={d}
          stroke="currentColor"
          strokeWidth={1}
          strokeLinecap="round"
        />
      ))}
    </svg>
  );
}

function elbow(
  startX: number,
  startY: number,
  endX: number,
  endY: number,
  midX: number
): string {
  if (Math.abs(startY - endY) <= 1) {
    return `M ${startX} ${startY} L ${endX} ${endY}`;
  }
  const radius = Math.min(8, Math.abs(startY - endY) / 2, Math.abs(midX - startX));
  const down = endY > startY;
  const turn1 = startY + (down ? radius : -radius);
  const turn2 = endY + (down ? -radius : radius);
  return [
    `M ${startX} ${startY}`,
    `L ${midX - radius} ${startY}`,
    `Q ${midX} ${startY} ${midX} ${turn1}`,
    `L ${midX} ${turn2}`,
    `Q ${midX} ${endY} ${midX + radius} ${endY}`,
    `L ${endX} ${endY}`,
  ].join(" ");
}

/** The fallback when nothing connects: plain columns, tightly stacked. */
function PlainColumn({ games }: { games: Game[] }) {
  return (
    <div className="flex flex-1 flex-col" style={{ gap: BRACKET_CARD_GAP }}>
      {games.map((game) => (
        <div key={game.id} style={{ height: BRACKET_CARD_HEIGHT }}>
          <MatchCard game={game} />
        </div>
      ))}
    </div>
  );
}

/**
 * A team that skipped this round. Quieter than a match card and half its
 * height — nothing happened here, and the card should say so without taking a
 * game's worth of space.
 */
function ByeCard({ team }: { team: Team }) {
  return (
    <div
      aria-label={`${team.school}, bye`}
      className="flex h-full items-center gap-1.5 rounded-[10px] border border-divider bg-bg-card px-2"
    >
      <TeamLogo
        team={team}
        teamName={team.school}
        size="sm"
        className="h-4 w-4 shrink-0 object-contain"
      />
      <span className="truncate type-row-name-em text-text-primary">
        {team.abbreviation || team.school}
      </span>
      <span className="ml-auto shrink-0 type-row-meta-medium tracking-wide text-text-secondary">
        BYE
      </span>
    </div>
  );
}

/**
 * One game in the bracket: its own compact card, not a row in a list.
 *
 * The loser gives up its ink rather than being struck through (FotMob
 * strikes; the app mutes, everywhere from a game row to the widget) — one
 * convention, and a strike-through would be the only one in the app. A
 * hairline, not the shadow the list cards wear: the connectors are hairlines
 * too, so the card edge and the line that meets it are the same stroke.
 */
function MatchCard({ game }: { game: Game }) {
  const state = gameState(game.status);
  const status = bracketStatusLine(game);
  return (
    <Link
      href={gamePath(game)}
      aria-label={spokenLabel(game, status)}
      suppressHydrationWarning
      className="flex h-full flex-col gap-1 rounded-[10px] border border-divider bg-bg-card p-2 transition-colors hover:bg-bg-header"
    >
      <span className="flex items-center gap-1.5">
        {state === "live" && (
          <span className="h-[5px] w-[5px] shrink-0 rounded-full bg-live-accent" />
        )}
        <span
          className={cn(
            "truncate type-row-meta-medium",
            state === "live" ? "text-text-primary" : "text-text-secondary"
          )}
        >
          {status}
        </span>
      </span>
      <BracketSide game={game} side={game.awayTeam} />
      <BracketSide game={game} side={game.homeTeam} />
    </Link>
  );
}

function BracketSide({ game, side }: { game: Game; side: GameTeam }) {
  // Only a decided game has a loser to mute — a pre-game card's two sides
  // are equals.
  const muted = game.status === "complete" && side.isWinner === false;
  return (
    <span className="flex items-center gap-1.5">
      <TeamLogo
        team={side.team}
        teamName={side.team.school}
        size="sm"
        className="h-4 w-4 shrink-0 object-contain"
      />
      {side.ranking !== undefined && (
        <span className="shrink-0 type-row-meta text-text-secondary">
          {side.ranking}
        </span>
      )}
      <span
        className={cn(
          "truncate",
          muted
            ? "type-row-name text-text-secondary"
            : "type-row-name-em text-text-primary"
        )}
      >
        {side.team.abbreviation || side.team.school}
      </span>
      {side.score !== null && (
        <span
          className={cn(
            "ml-auto shrink-0 tnum",
            muted
              ? "type-row-name text-text-secondary"
              : "type-row-name-em text-text-primary"
          )}
        >
          {side.score}
        </span>
      )}
    </span>
  );
}

function bracketStatusLine(game: Game): string {
  switch (gameState(game.status)) {
    case "final":
      return game.statusDetail?.toUpperCase().includes("OT")
        ? "Final/OT"
        : "Final";
    case "live":
      return (
        liveStatusText({
          livePhase: game.livePhase,
          quarter: game.quarter,
          clock: game.clock,
          detail: game.statusDetail,
        }) ?? "Live"
      );
    case "other":
      return otherStatusText(game);
    case "pre": {
      const date = new Date(game.scheduledAt);
      if (Number.isNaN(date.getTime())) return "TBD";
      return game.timeTBD
        ? date.toLocaleDateString("en-US", { month: "numeric", day: "numeric" })
        : date.toLocaleString("en-US", {
            month: "numeric",
            day: "numeric",
            hour: "numeric",
            minute: "2-digit",
          });
    }
  }
}

function spokenLabel(game: Game, status: string): string {
  const parts: string[] = [];
  if (game.headline) parts.push(game.headline);
  parts.push(`${game.awayTeam.team.school} at ${game.homeTeam.team.school}`);
  if (game.awayTeam.score !== null && game.homeTeam.score !== null) {
    parts.push(`${game.awayTeam.score} to ${game.homeTeam.score}`);
  }
  parts.push(status);
  return parts.join(", ");
}
