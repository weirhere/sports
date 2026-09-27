"use client";

// ESPN's Gamecast, as a card — the web twin of iOS `LiveSituationCard`
// (2026-09-27), in every league: three labeled columns across the top, the
// surface beneath them — football's field, basketball's court, hockey's
// rink — and the last play under that. Live games only. Football's is built
// from `drives.current`, which ESPN drops the moment a game ends; the court
// and rink are gated on the game being live by the page.
//
// The card doesn't know which league it's showing: it prints a
// `GamecastContent` (lib/gamecast.ts), and each league builds one.
//
// Nothing on it moves when the game does. The three columns are equal
// thirds, so the middle one stays centered however wide the others get; the
// result line shares the columns' grid cell rather than replacing them; and
// the last play always reserves two lines. A card polled every second can't
// be allowed to jump.

import type { ReactNode } from "react";
import type { Game, GameSituation } from "@/lib/types";
import {
  footballGamecast,
  type GamecastContent,
  type GamecastSlot,
  type ShotMap,
} from "@/lib/gamecast";
import { cn } from "@/lib/utils";
import { TeamMark } from "./team-mark";
import { DriveField } from "./gamecast/drive-field";
import { CourtSurface } from "./gamecast/court-surface";
import { RinkSurface } from "./gamecast/rink-surface";

/** Football's card: the drive on the field. */
export function DriveGamecastCard({
  game,
  situation,
}: {
  game: Game;
  situation: GameSituation;
}) {
  const offense = [game.awayTeam, game.homeTeam].find(
    (side) => String(side.team.espnId) === situation.possessionTeamId
  );
  return (
    <LiveSituationCard
      content={footballGamecast(game, situation)}
      surface={
        situation.field && (
          <DriveField
            // A new possession is a new field: the pin starts where the
            // drive does rather than sliding over from the last one.
            key={situation.driveId}
            field={situation.field}
            away={game.awayTeam}
            home={game.homeTeam}
            offenseLogoUrl={offense?.team.logoUrl}
            playId={situation.lastPlayId}
          />
        )
      }
    />
  );
}

/** Basketball's and hockey's card: this period's shots on the court or
 *  rink, keyed by period so the surface clears at each break. */
export function ShotGamecastCard({
  game,
  content,
  map,
}: {
  game: Game;
  content: GamecastContent;
  map: ShotMap;
}) {
  const Surface = map.surface === "court" ? CourtSurface : RinkSurface;
  return (
    <LiveSituationCard
      content={content}
      surface={
        <Surface
          key={map.period}
          map={map}
          away={game.awayTeam}
          home={game.homeTeam}
        />
      }
    />
  );
}

function LiveSituationCard({
  content,
  surface,
}: {
  content: GamecastContent;
  surface?: ReactNode;
}) {
  return (
    <div
      role="group"
      aria-label={content.accessibilitySummary}
      className="flex flex-col gap-3 px-4 pb-2 pt-3"
    >
      <div aria-hidden="true" className="flex flex-col gap-3">
        {/* The columns and the result share one cell, both always laid out,
            so a touchdown trades one for the other without the field
            moving. */}
        <div className="grid">
          <div
            className={cn(
              "col-start-1 row-start-1 grid grid-cols-3 items-baseline",
              content.result && "invisible"
            )}
          >
            {content.slots.map((slot, index) => (
              <Column
                key={slot.label}
                slot={slot}
                align={index === 0 ? "start" : index === 2 ? "end" : "center"}
              />
            ))}
          </div>
          <div
            className={cn(
              "col-start-1 row-start-1 flex items-center justify-center gap-2",
              !content.result && "invisible"
            )}
          >
            {content.resultTeam && (
              <TeamMark
                logoUrl={content.resultTeam.logoUrl}
                alt=""
                size={20}
                className="h-5 w-5 object-contain"
              />
            )}
            <span className="type-section-header-prominent tracking-[0.1em] text-text-primary uppercase">
              {content.result}
            </span>
          </div>
        </div>
        <div className="-mx-4 border-t border-divider" />
        {surface && (
          <>
            {surface}
            <div className="-mx-4 border-t border-divider" />
          </>
        )}
        <LastPlay content={content} />
      </div>
    </div>
  );
}

function Column({
  slot,
  align,
}: {
  slot: GamecastSlot;
  align: "start" | "center" | "end";
}) {
  return (
    <div
      className={cn(
        "flex min-w-0 flex-col gap-[3px]",
        align === "start" && "items-start text-left",
        align === "center" && "items-center text-center",
        align === "end" && "items-end text-right"
      )}
    >
      <span className="type-row-meta tracking-[0.07em] text-text-secondary uppercase">
        {slot.label}
      </span>
      <span className="max-w-full truncate type-team-name tnum text-text-primary">
        {slot.value ?? "—"}
      </span>
    </div>
  );
}

function LastPlay({ content }: { content: GamecastContent }) {
  return (
    <div className="flex flex-col gap-[3px]">
      <div className="flex items-baseline gap-2">
        <span className="min-w-0 truncate type-row-meta tracking-[0.07em] text-text-secondary uppercase">
          {content.lastPlayLabel}
        </span>
        {content.lastPlayClock && (
          <span className="ml-auto shrink-0 type-row-meta tnum text-text-secondary">
            {content.lastPlayClock}
          </span>
        )}
      </div>
      {/* Two lines are always held, so a one-line run followed by a
          two-line touchdown doesn't change the card's height. A third is
          allowed for the long ones — penalties, mostly — and is the only
          way the card grows. */}
      <p className="line-clamp-3 min-h-[2lh] type-team-name text-text-primary">
        {content.lastPlayText}
      </p>
    </div>
  );
}
