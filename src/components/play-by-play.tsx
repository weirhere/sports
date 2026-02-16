"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";
import type { Play, GameTeam } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { cn } from "@/lib/utils";

interface PlayByPlayProps {
  plays: Play[];
  homeTeam: GameTeam;
  awayTeam: GameTeam;
}

export function PlayByPlay({ plays, homeTeam, awayTeam }: PlayByPlayProps) {
  const quarters = groupByQuarter(plays);
  const [openQuarters, setOpenQuarters] = useState<Set<number>>(
    new Set(Object.keys(quarters).map(Number))
  );

  if (plays.length === 0) {
    return (
      <p className="py-6 text-center text-sm text-muted-foreground">
        No play-by-play data available.
      </p>
    );
  }

  function toggleQuarter(q: number) {
    setOpenQuarters((prev) => {
      const next = new Set(prev);
      if (next.has(q)) next.delete(q);
      else next.add(q);
      return next;
    });
  }

  return (
    <div className="space-y-2">
      {Object.entries(quarters).map(([q, qPlays]) => {
        const quarter = Number(q);
        const isOpen = openQuarters.has(quarter);
        const label = quarter > 4 ? `Overtime` : `Quarter ${quarter}`;

        return (
          <div key={quarter}>
            <button
              onClick={() => toggleQuarter(quarter)}
              className="flex w-full items-center gap-2 rounded-lg bg-muted/50 px-3 py-2 text-left"
            >
              <span className="text-sm font-semibold">{label}</span>
              <span className="text-xs text-muted-foreground">
                ({qPlays.length} plays)
              </span>
              <ChevronDown
                className={cn(
                  "ml-auto h-4 w-4 text-muted-foreground transition-transform",
                  isOpen && "rotate-180"
                )}
              />
            </button>

            {isOpen && (
              <div className="mt-1 space-y-0.5 pl-2">
                {qPlays.map((play) => {
                  const team =
                    play.team === "home" ? homeTeam : awayTeam;
                  return (
                    <div
                      key={play.id}
                      className={cn(
                        "flex items-start gap-2 rounded px-2 py-1.5 text-sm",
                        play.scoringPlay &&
                          "bg-green-50 dark:bg-green-950/20"
                      )}
                    >
                      <span className="shrink-0 font-score text-xs text-muted-foreground">
                        {play.clock}
                      </span>
                      <TeamLogo
                        espnId={team.team.espnId}
                        teamName={team.team.school}
                        size="sm"
                        className="mt-0.5 shrink-0"
                      />
                      <div className="flex-1">
                        {play.down && play.distance && (
                          <span className="mr-1.5 text-xs font-medium text-muted-foreground">
                            {play.down}
                            {ordinal(play.down)} &amp; {play.distance}
                          </span>
                        )}
                        <span className="text-sm">{play.description}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function groupByQuarter(plays: Play[]): Record<number, Play[]> {
  const groups: Record<number, Play[]> = {};
  for (const play of plays) {
    if (!groups[play.quarter]) groups[play.quarter] = [];
    groups[play.quarter].push(play);
  }
  return groups;
}

function ordinal(n: number): string {
  if (n === 1) return "st";
  if (n === 2) return "nd";
  if (n === 3) return "rd";
  return "th";
}
