import type { DayGames } from "@/lib/types";
import { ConferenceGroup } from "./conference-group";

interface DayGroupProps {
  dayGames: DayGames;
  defaultOpen?: boolean;
}

export function DayGroup({ dayGames, defaultOpen = true }: DayGroupProps) {
  return (
    <div>
      <div className="sticky top-14 z-10 -mx-4 bg-background/95 px-4 py-2 backdrop-blur supports-[backdrop-filter]:bg-background/60 sm:top-16">
        <h2 className="text-base font-semibold">{dayGames.label}</h2>
      </div>

      <div className="space-y-1">
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
