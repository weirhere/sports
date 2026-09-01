"use client";

import { useState } from "react";
import { ChevronUp } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import type { Game, Conference } from "@/lib/types";
import { GameRow } from "./game-row";
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
    <div className="overflow-hidden rounded-xl border bg-card shadow-card">
      {/* Conference header */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex w-full items-center gap-3 px-4 py-3 text-left bg-muted/50 transition-colors hover:bg-accent/30"
      >
        <span className="text-sm font-semibold text-foreground">
          {conference.shortName}
        </span>
        <motion.span
          animate={{ rotate: isOpen ? 0 : 180 }}
          transition={{ duration: 0.2 }}
          className="ml-auto"
        >
          <ChevronUp className="h-4 w-4 text-muted-foreground" />
        </motion.span>
      </button>

      {/* Game rows */}
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0 }}
            animate={{ height: "auto" }}
            exit={{ height: 0 }}
            transition={{ duration: 0.2, ease: "easeInOut" }}
            className="overflow-hidden"
          >
            <div className="border-t">
              {games.map((game, i) => (
                <div key={game.id}>
                  {i > 0 && <div className="mx-4 border-t" />}
                  <GameRow game={game} />
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
