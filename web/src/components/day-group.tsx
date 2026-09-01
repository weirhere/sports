"use client";

import { useRef, useState, useEffect } from "react";
import type { DayGames } from "@/lib/types";
import { ConferenceGroup } from "./conference-group";
import { cn } from "@/lib/utils";

interface DayGroupProps {
  dayGames: DayGames;
  defaultOpen?: boolean;
}

export function DayGroup({ dayGames, defaultOpen = true }: DayGroupProps) {
  const sentinelRef = useRef<HTMLDivElement>(null);
  const [isStuck, setIsStuck] = useState(false);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel) return;

    const observer = new IntersectionObserver(
      ([entry]) => setIsStuck(!entry.isIntersecting),
      { threshold: 0 }
    );

    observer.observe(sentinel);
    return () => observer.disconnect();
  }, []);

  return (
    <div>
      {/* Sentinel: when this scrolls out of view, the header is stuck */}
      <div ref={sentinelRef} className="h-0" />
      <div
        className={cn(
          "sticky top-[100px] z-10 -mx-4 bg-background px-4 py-2 sm:top-[108px]",
          isStuck ? "border-b border-border" : "border-b border-transparent"
        )}
      >
        <h2 className="text-base font-semibold">{dayGames.label}</h2>
      </div>

      <div className="space-y-3">
        {dayGames.conferenceGroups.map((group) => (
          <ConferenceGroup
            key={group.conference.id}
            conference={group.conference}
            games={group.games}
            defaultOpen={defaultOpen}
          />
        ))}
      </div>
    </div>
  );
}
