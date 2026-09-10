"use client";

// The Following section's cards, reorderable by dragging — a port of iOS
// `FollowedTablesList` (2026-09-06, rebuilt 2026-09-07).
//
// **Why not the platform's own drag.** HTML5 drag-and-drop is built for
// carrying an item *out* of a list: it detaches a small ghost from the
// pointer, shows a copy cursor on what is a reorder, leaves the source card
// sitting in place, and moves nothing until the drop lands. A reorder should
// read as moving the card, so the card is what moves. Same conclusion iOS
// reached about `.draggable`/`.dropDestination`.
//
// **The order is one order.** It is the order these tables lead the Scores
// page in, one tab over — one list, one order, both screens. A set saved
// before dragging existed falls back to the hub's own tier order, so nothing
// needs migrating.
//
// A drag is not an accessible affordance, so every card also carries Move
// up / Move down buttons.

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ChevronDown, ChevronUp, GripVertical } from "lucide-react";
import type { ConferenceStandingsGroup, Poll } from "@/lib/types";
import {
  tableLogoUrl,
  tableName,
  tableToken,
  type FollowedTable,
} from "@/lib/followed-tables";
import { leaderOf, leaderRecord, isLeagueWide } from "@/lib/standings-tables";
import { conferencePath } from "@/lib/routes";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { cn } from "@/lib/utils";

/** How long a press on the card body waits before it becomes a lift. */
const LIFT_DELAY_MS = 350;
/** How far a press may drift before it's a scroll, not a lift. */
const LIFT_TOLERANCE_PX = 8;
/** The `gap-3` between cards, in px — what a neighbour travels past. */
const CARD_GAP_PX = 12;

interface FollowedTablesListProps {
  /** The followed tables, already in the user's order. */
  tables: FollowedTable[];
  order: string[];
  onReorder: (order: string[]) => void;
  /** The loaded standings behind a table, for its leader teaser. */
  resolve: (table: FollowedTable) => ConferenceStandingsGroup | undefined;
  polls: Poll[];
}

export function FollowedTablesList({
  tables,
  onReorder,
  resolve,
  polls,
}: FollowedTablesListProps) {
  const [lifted, setLifted] = useState<number | null>(null);
  const [offset, setOffset] = useState(0);
  const [target, setTarget] = useState<number | null>(null);
  // The lifted card's own height, captured at lift. State rather than a
  // ref because the neighbours' shift is computed during render, and a ref
  // read there isn't reactive.
  const [liftedHeight, setLiftedHeight] = useState(0);

  const containerRef = useRef<HTMLDivElement>(null);
  const heights = useRef<number[]>([]);
  const startY = useRef(0);
  const liftTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingLift = useRef<{ index: number; y: number } | null>(null);

  const commit = useCallback(
    (from: number, to: number) => {
      if (from === to) return;
      const next = [...tables];
      const [moved] = next.splice(from, 1);
      next.splice(to, 0, moved);
      onReorder(next.map(tableToken));
    },
    [tables, onReorder]
  );

  const cancelPending = () => {
    if (liftTimer.current !== null) {
      clearTimeout(liftTimer.current);
      liftTimer.current = null;
    }
    pendingLift.current = null;
  };

  const measure = () => {
    const container = containerRef.current;
    if (!container) return;
    heights.current = [...container.children].map(
      (child) => child.getBoundingClientRect().height
    );
  };

  const beginLift = (index: number, y: number) => {
    measure();
    startY.current = y;
    setLiftedHeight(heights.current[index] ?? 0);
    setLifted(index);
    setTarget(index);
    setOffset(0);
  };

  // The whole gesture lives on the window once a lift starts, so the card
  // keeps tracking even when the pointer leaves it.
  useEffect(() => {
    if (lifted === null) return;

    const onMove = (event: PointerEvent) => {
      event.preventDefault();
      const delta = event.clientY - startY.current;
      setOffset(delta);

      // Which slot the card's own centre is over now. Walking measured
      // heights rather than assuming a uniform row keeps this honest when
      // a card wraps to two lines.
      const sizes = heights.current;
      let index = lifted;
      let travelled = 0;
      if (delta > 0) {
        for (let i = lifted + 1; i < sizes.length; i += 1) {
          travelled += sizes[i];
          if (delta > travelled - sizes[i] / 2) index = i;
        }
      } else {
        for (let i = lifted - 1; i >= 0; i -= 1) {
          travelled += sizes[i];
          if (-delta > travelled - sizes[i] / 2) index = i;
        }
      }
      setTarget(index);
    };

    const onUp = () => {
      if (target !== null) commit(lifted, target);
      setLifted(null);
      setTarget(null);
      setOffset(0);
      setLiftedHeight(0);
    };

    window.addEventListener("pointermove", onMove, { passive: false });
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };
  }, [lifted, target, commit]);

  const move = (from: number, to: number) => {
    if (to < 0 || to >= tables.length) return;
    commit(from, to);
  };

  return (
    <div
      ref={containerRef}
      className={cn(
        "flex flex-col gap-3",
        // The page's own scroll stands down for the length of a lift, so
        // the two aren't competing for the same vertical pan.
        lifted !== null && "touch-none select-none"
      )}
    >
      {tables.map((table, index) => {
        const isLifted = index === lifted;
        // Where this card sits while another one is passing it.
        const step = liftedHeight + CARD_GAP_PX;
        const shift =
          lifted === null || target === null || isLifted
            ? 0
            : index > lifted && index <= target
              ? -step
              : index < lifted && index >= target
                ? step
                : 0;

        return (
          <div
            key={tableToken(table)}
            style={{
              transform: isLifted
                ? `translateY(${offset}px)`
                : `translateY(${shift}px)`,
              transition: isLifted ? "none" : "transform 180ms ease-out",
              zIndex: isLifted ? 10 : undefined,
              position: "relative",
            }}
            onPointerDown={(event) => {
              if (event.button !== 0) return;
              pendingLift.current = { index, y: event.clientY };
              liftTimer.current = setTimeout(() => {
                const pending = pendingLift.current;
                if (pending) beginLift(pending.index, pending.y);
              }, LIFT_DELAY_MS);
            }}
            onPointerMove={(event) => {
              const pending = pendingLift.current;
              if (!pending) return;
              // Drifted before the press matured: that's a scroll.
              if (Math.abs(event.clientY - pending.y) > LIFT_TOLERANCE_PX) {
                cancelPending();
              }
            }}
            onPointerUp={cancelPending}
            onPointerCancel={cancelPending}
          >
            <FollowedTableCard
              table={table}
              standings={resolve(table)}
              polls={polls}
              isLifted={isLifted}
              // The grip lifts with no press at all — a pointer user
              // shouldn't have to wait out a delay meant for touch.
              onGripDown={(y) => {
                cancelPending();
                beginLift(index, y);
              }}
              onMoveUp={index > 0 ? () => move(index, index - 1) : undefined}
              onMoveDown={
                index < tables.length - 1
                  ? () => move(index, index + 1)
                  : undefined
              }
            />
          </div>
        );
      })}
    </div>
  );
}

function FollowedTableCard({
  table,
  standings,
  polls,
  isLifted,
  onGripDown,
  onMoveUp,
  onMoveDown,
}: {
  table: FollowedTable;
  standings?: ConferenceStandingsGroup;
  polls: Poll[];
  isLifted: boolean;
  onGripDown: (y: number) => void;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
}) {
  const name = tableName(table);
  const href =
    table.kind === "poll" ? "/rankings/poll" : conferencePath(table.ref);

  const teaser = (() => {
    if (table.kind === "poll") {
      const top = polls[0]?.ranks[0];
      return top ? `#1 ${top.team.school}` : undefined;
    }
    if (!standings || isLeagueWide(standings)) return undefined;
    const leader = leaderOf(standings);
    const record = leader ? leaderRecord(leader) : undefined;
    return leader && record ? `${leader.team.school} · ${record}` : undefined;
  })();

  return (
    <section
      className={cn(
        "flex min-h-12 items-center gap-1 pr-1 card-surface",
        isLifted && "shadow-lg"
      )}
    >
      {/* Content stops hit-testing while anything is lifted, so a drag
          can't end as a navigation. */}
      <Link
        href={href}
        draggable={false}
        className={cn(
          "flex min-w-0 flex-1 items-center gap-3 self-stretch px-4 py-[7px] transition-colors hover:bg-bg-header",
          isLifted && "pointer-events-none"
        )}
      >
        <ConferenceLogo src={tableLogoUrl(table)} name="" />
        <span className="shrink-0 type-team-name text-text-primary">
          {name}
        </span>
        {teaser && (
          <span className="truncate type-meta text-text-secondary">
            {teaser}
          </span>
        )}
      </Link>

      <div className="flex shrink-0 items-center">
        {/* A drag is not an accessible affordance. */}
        <button
          type="button"
          onClick={onMoveUp}
          disabled={onMoveUp === undefined}
          aria-label={`Move ${name} up`}
          className="flex h-8 w-7 items-center justify-center rounded text-text-secondary transition-colors hover:text-text-primary disabled:opacity-25"
        >
          <ChevronUp aria-hidden="true" className="h-4 w-4" />
        </button>
        <button
          type="button"
          onClick={onMoveDown}
          disabled={onMoveDown === undefined}
          aria-label={`Move ${name} down`}
          className="flex h-8 w-7 items-center justify-center rounded text-text-secondary transition-colors hover:text-text-primary disabled:opacity-25"
        >
          <ChevronDown aria-hidden="true" className="h-4 w-4" />
        </button>
        <span
          role="presentation"
          onPointerDown={(event) => {
            if (event.button !== 0) return;
            event.preventDefault();
            onGripDown(event.clientY);
          }}
          aria-hidden="true"
          className="flex h-8 w-7 cursor-grab touch-none items-center justify-center text-text-secondary active:cursor-grabbing"
        >
          <GripVertical className="h-4 w-4" />
        </span>
      </div>
    </section>
  );
}
