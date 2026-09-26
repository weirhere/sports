"use client";

// The Following section's cards — a port of iOS `FollowedTablesList`
// (2026-09-06, rebuilt 2026-09-07, Edit/Done 2026-09-25).
//
// **Edit mode.** Arranging and unfollowing live behind an Edit link on the
// section's heading, which reads Done while it's on (Andy, 2026-09-25, from
// FotMob's Leagues tab). Outside it a card is only its row: no grip, no move
// buttons, no gesture of any kind, so the page scrolls over these cards
// exactly as it scrolls over the list below them. In it, each card gains a
// leading dismiss button and a trailing grip, and stops navigating. That
// replaces a press-and-hold on every card, which kept picking cards up out of
// ordinary scrolls on a phone however long the hold was tuned to.
//
// **Why not the platform's own drag.** HTML5 drag-and-drop is built for
// carrying an item *out* of a list: it detaches a small ghost from the
// pointer, shows a copy cursor on what is a reorder, leaves the source card
// sitting in place, and moves nothing until the drop lands. A reorder should
// read as moving the card, so the card is what moves. Same conclusion iOS
// reached about `.draggable`/`.dropDestination`.
//
// **The order is one order.** It is the order these tables lead the Scores
// page in, one tab over. A drop resolves against the cards on screen and
// saves the whole order, hidden tables included (`moveAmongVisible`).
//
// A drag is not an accessible affordance, so edit mode also gives every card
// Move up / Move down buttons, and the Edit link is an ordinary button.

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { ChevronDown, ChevronUp, GripVertical, Minus } from "lucide-react";
import {
  moveAmongVisible,
  tableLeague,
  tableLogoUrl,
  tableName,
  tableToken,
  type FollowedTable,
} from "@/lib/followed-tables";
import { displayName, shortName } from "@/lib/leagues";
import { conferencePath } from "@/lib/routes";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { cn } from "@/lib/utils";

/** The `gap-3` between cards, in px — what a neighbour travels past. */
const CARD_GAP_PX = 12;

interface FollowedTablesListProps {
  /** The cards on screen: the followed tables that loaded, in order. */
  tables: FollowedTable[];
  /** Every followed table in the user's order, loaded or not. */
  allTables: FollowedTable[];
  isEditing: boolean;
  onReorder: (order: string[]) => void;
  onUnfollow: (table: FollowedTable) => void;
}

export function FollowedTablesList({
  tables,
  allTables,
  isEditing,
  onReorder,
  onUnfollow,
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

  const commit = useCallback(
    (from: number, to: number) => {
      if (from === to) return;
      onReorder(moveAmongVisible(allTables, tables[from], to, tables));
    },
    [allTables, tables, onReorder]
  );

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

  const endLift = useCallback(() => {
    setLifted(null);
    setTarget(null);
    setOffset(0);
    setLiftedHeight(0);
  }, []);

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
      endLift();
    };

    window.addEventListener("pointermove", onMove, { passive: false });
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };
  }, [lifted, target, commit, endLift]);

  const move = (from: number, to: number) => {
    if (to < 0 || to >= tables.length) return;
    commit(from, to);
  };

  const reorderable = isEditing && tables.length > 1;

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
          >
            <FollowedTableCard
              table={table}
              isEditing={isEditing}
              isReorderable={reorderable}
              isLifted={isLifted}
              onUnfollow={() => onUnfollow(table)}
              // Edit mode already said this is a reorder, so the grip lifts
              // on press, with no hold to wait out — iOS's `List` reorder
              // control does the same.
              onGripDown={(y) => beginLift(index, y)}
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
  isEditing,
  isReorderable,
  isLifted,
  onUnfollow,
  onGripDown,
  onMoveUp,
  onMoveDown,
}: {
  table: FollowedTable;
  isEditing: boolean;
  isReorderable: boolean;
  isLifted: boolean;
  onUnfollow: () => void;
  onGripDown: (y: number) => void;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
}) {
  const reducedMotion = useReducedMotion();
  const name = tableName(table);
  const league = tableLeague(table);
  // "SEC - NCAAF", as the Scores section headers read (iOS, 2026-09-25):
  // this list mixes every league, and "Eastern" is two different tables.
  // A table named for its own league ("NFL") stays bare.
  const tagged = name !== displayName(league) && name !== shortName(league);
  const title = tagged ? `${name} - ${shortName(league)}` : name;
  const spoken = tagged ? `${name}, ${displayName(league)}` : name;
  const href =
    table.kind === "poll" ? "/rankings/poll" : conferencePath(table.ref);

  // The controls slide in from the card's own edges; Reduce Motion gets the
  // fade alone. Width animates too, so the name eases over rather than
  // jumping when the dismiss button arrives.
  const controlMotion = (edge: "leading" | "trailing") => ({
    initial: reducedMotion
      ? { opacity: 0 }
      : { opacity: 0, width: 0, x: edge === "leading" ? -12 : 12 },
    animate: reducedMotion
      ? { opacity: 1 }
      : { opacity: 1, width: "auto", x: 0 },
    exit: reducedMotion
      ? { opacity: 0 }
      : { opacity: 0, width: 0, x: edge === "leading" ? -12 : 12 },
    transition: { duration: 0.22, ease: [0.2, 0, 0, 1] as const },
  });

  const identity = (
    <>
      <ConferenceLogo src={tableLogoUrl(table)} name="" />
      <span className="sr-only">{spoken}</span>
      {/* No first-place teaser (iOS, 2026-09-21; Andy, 2026-09-25): the
          card answers "which table", and a leader and a record answered a
          different question in the same row. */}
      <span
        aria-hidden="true"
        className="min-w-0 truncate type-team-name text-text-primary"
      >
        {title}
      </span>
    </>
  );

  return (
    <section
      className={cn(
        // A fixed minimum the edit controls fit inside, so a card keeps its
        // height when they appear (Andy, 2026-09-25: only the controls
        // should change).
        "flex min-h-12 items-center overflow-hidden card-surface",
        isLifted && "shadow-lg"
      )}
    >
      <AnimatePresence initial={false}>
        {isEditing && (
          <motion.span
            key="dismiss"
            className="flex shrink-0 overflow-hidden"
            {...controlMotion("leading")}
          >
            {/* Gray, not red: the app's one red is the live accent, and a
                removal one star below undoes doesn't need an alarm. */}
            <button
              type="button"
              onClick={onUnfollow}
              aria-label={`Unfollow ${spoken}`}
              className="-mr-2 ml-1 flex h-10 w-10 items-center justify-center"
            >
              <span className="flex h-[18px] w-[18px] items-center justify-center rounded-full bg-text-secondary text-bg-card">
                <Minus aria-hidden="true" className="h-3 w-3" strokeWidth={3} />
              </span>
            </button>
          </motion.span>
        )}
      </AnimatePresence>

      {isEditing ? (
        // In edit mode a card is something being arranged, not a link: a
        // tap aimed at a control that lands a few pixels off shouldn't
        // navigate.
        // `pl-2`: the dismiss target already carries its own inset, so the
        // row's 16px would leave a gap iOS tightened away.
        <div className="flex min-w-0 flex-1 items-center gap-3 self-stretch py-[7px] pl-2 pr-4">
          {identity}
        </div>
      ) : (
        <Link
          href={href}
          draggable={false}
          className="flex min-w-0 flex-1 items-center gap-3 self-stretch px-4 py-[7px] transition-colors hover:bg-bg-header"
        >
          {identity}
        </Link>
      )}

      <AnimatePresence initial={false}>
        {isReorderable && (
          <motion.span
            key="reorder"
            className="flex shrink-0 items-center overflow-hidden pr-1"
            {...controlMotion("trailing")}
          >
            {/* A drag is not an accessible affordance, so the keyboard and
                screen readers get Move up / Move down. Visually hidden until
                focused: on a phone they cost the name ~56px, and iOS shows
                only the grip. */}
            <button
              type="button"
              onClick={onMoveUp}
              disabled={onMoveUp === undefined}
              aria-label={`Move ${spoken} up`}
              className="sr-only flex h-8 w-7 items-center justify-center rounded text-text-secondary transition-colors hover:text-text-primary focus-visible:not-sr-only disabled:opacity-25"
            >
              <ChevronUp aria-hidden="true" className="h-4 w-4" />
            </button>
            <button
              type="button"
              onClick={onMoveDown}
              disabled={onMoveDown === undefined}
              aria-label={`Move ${spoken} down`}
              className="sr-only flex h-8 w-7 items-center justify-center rounded text-text-secondary transition-colors hover:text-text-primary focus-visible:not-sr-only disabled:opacity-25"
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
              className="flex h-8 w-8 cursor-grab touch-none items-center justify-center text-text-secondary active:cursor-grabbing"
            >
              <GripVertical className="h-4 w-4" />
            </span>
          </motion.span>
        )}
      </AnimatePresence>
    </section>
  );
}
