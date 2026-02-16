"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";
import type { Game, Conference } from "@/lib/types";
import { GameCard } from "./game-card";
import { cn } from "@/lib/utils";

interface ConferenceGroupProps {
  conference: Conference;
  games: Game[];
  defaultOpen?: boolean;
}

export function ConferenceGroup({
  conference,
  games,
  defaultOpen = true,
}: ConferenceGroupProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <div>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex w-full items-center gap-2 py-2 text-left"
      >
        <span className="text-sm font-semibold text-foreground">
          {conference.shortName}
        </span>
        <span className="text-xs text-muted-foreground">
          {games.length} {games.length === 1 ? "game" : "games"}
        </span>
        <ChevronDown
          className={cn(
            "ml-auto h-4 w-4 text-muted-foreground transition-transform",
            isOpen && "rotate-180"
          )}
        />
      </button>

      {isOpen && (
        <div className="grid gap-3 pb-4 sm:grid-cols-2 lg:grid-cols-3">
          {games.map((game) => (
            <GameCard key={game.id} game={game} />
          ))}
        </div>
      )}
    </div>
  );
}
