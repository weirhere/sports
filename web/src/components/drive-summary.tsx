import type { ScoringDrive, GameTeam } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { cn } from "@/lib/utils";

interface DriveSummaryProps {
  drives: ScoringDrive[];
  homeTeam: GameTeam;
  awayTeam: GameTeam;
}

export function DriveSummary({
  drives,
  homeTeam,
  awayTeam,
}: DriveSummaryProps) {
  if (drives.length === 0) {
    return (
      <p className="py-6 text-center text-sm text-muted-foreground">
        No scoring drives available.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      {drives.map((drive, i) => {
        const team = drive.team === "home" ? homeTeam : awayTeam;
        return (
          <div
            key={i}
            className="flex items-start gap-3 rounded-lg border p-3"
          >
            <TeamLogo
              espnId={team.team.espnId}
              teamName={team.team.school}
              size="sm"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-semibold uppercase text-muted-foreground">
                  Q{drive.quarter}
                </span>
                <span
                  className={cn(
                    "rounded px-1.5 py-0.5 text-xs font-medium",
                    drive.result === "Touchdown"
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted text-muted-foreground"
                  )}
                >
                  {drive.result}
                </span>
              </div>
              <p className="mt-1 text-sm">{drive.description}</p>
              <p className="mt-1 text-xs text-muted-foreground">
                {drive.plays} plays, {drive.yards} yds, {drive.timeOfPossession}
              </p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
