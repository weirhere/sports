"use client";

// A Games tab's season slate — iOS `ConferenceGamesList`
// (Features/Conference/ConferenceGamesList.swift): one card per week in
// season order (or per day, or one card for the lot), rows the same matchup
// language as everywhere else, tapping through to game detail.
//
// Mid-season the cards already played fold behind one "Earlier games" row,
// so the pane opens on the card holding the next game **with the page still
// at its true top** (iOS, 2026-09-08). Expanding pushes the next game's card
// down rather than moving it, which is what keeps the season in order: the
// history lands above the card it happened before.

import { useState } from "react";
import Link from "next/link";
import { ChevronDown } from "lucide-react";
import {
  foldSlate,
  slateGroups,
  type SlateGroup,
  type SlateGrouping,
} from "@/lib/conference-slate";
import type { Game } from "@/lib/types";
import { gamePath } from "@/lib/routes";
import { CardHeader } from "@/components/card-header";
import { GameMatchupRow, gameRowLabel } from "@/components/next-game-card";
import { cn } from "@/lib/utils";

export function ConferenceGamesList({
  games,
  grouping = "week",
}: {
  games: Game[];
  /** Weeks is a season's own clock and stays the default; the toggles can
   *  ask for days instead, or for one unheaded card. */
  grouping?: SlateGrouping;
}) {
  // Held across a season, grouping or filter change on purpose: a user who
  // asked for the history once shouldn't have to ask again to flip back.
  const [showsEarlier, setShowsEarlier] = useState(false);
  const fold = foldSlate(slateGroups(games, grouping));

  return (
    <div className="flex flex-col gap-2">
      {fold.earlier.length > 0 && (
        <>
          <EarlierGamesRow
            count={fold.earlier.reduce(
              (total, group) => total + group.games.length,
              0
            )}
            isExpanded={showsEarlier}
            onToggle={() => setShowsEarlier((was) => !was)}
          />
          {showsEarlier &&
            fold.earlier.map((group) => (
              <SlateCard key={group.id} group={group} />
            ))}
        </>
      )}
      {fold.upcoming.map((group) => (
        <SlateCard key={group.id} group={group} />
      ))}
    </div>
  );
}

/** The fold's one row: what's behind it, and the way in. */
function EarlierGamesRow({
  count,
  isExpanded,
  onToggle,
}: {
  count: number;
  isExpanded: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-expanded={isExpanded}
      aria-label={`Earlier games, ${count} ${count === 1 ? "game" : "games"}`}
      className="card-surface flex w-full items-center gap-2 p-3 text-left transition-colors hover:bg-bg-header"
    >
      <span className="type-section-header text-text-primary">Earlier games</span>
      <span className="tnum type-meta text-text-secondary">{count}</span>
      <ChevronDown
        aria-hidden="true"
        className={cn(
          "ml-auto h-3.5 w-3.5 shrink-0 text-text-secondary transition-transform",
          isExpanded && "rotate-180"
        )}
      />
    </button>
  );
}

function SlateCard({ group }: { group: SlateGroup }) {
  return (
    <section className="card-surface pb-1">
      {/* An unheaded card is the ungrouped list's whole point — nothing is
          being grouped, so nothing labels it. */}
      {group.title !== "" && <CardHeader title={group.title} />}
      {group.games.map((game, index) => (
        <div key={game.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
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
  );
}
