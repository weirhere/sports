import type { GameTeam } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { cn } from "@/lib/utils";

interface BoxScoreProps {
  homeTeam: GameTeam;
  awayTeam: GameTeam;
}

function TeamScoreRow({
  gameTeam,
  isWinner,
}: {
  gameTeam: GameTeam;
  isWinner: boolean;
}) {
  const quarters = gameTeam.linescores || [];
  const total = gameTeam.score ?? 0;

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <TeamLogo
            espnId={gameTeam.team.espnId}
            teamName={gameTeam.team.school}
            size="sm"
          />
          <span className={cn("text-sm", isWinner && "font-semibold")}>
            {gameTeam.team.abbreviation}
          </span>
        </div>
      </TableCell>
      {[0, 1, 2, 3].map((qi) => (
        <TableCell key={qi} className="font-score text-center text-sm">
          {quarters[qi] ?? "-"}
        </TableCell>
      ))}
      {quarters.length > 4 && (
        <TableCell className="font-score text-center text-sm">
          {quarters[4]}
        </TableCell>
      )}
      <TableCell
        className={cn(
          "font-score text-center text-sm",
          isWinner && "font-bold"
        )}
      >
        {total}
      </TableCell>
    </TableRow>
  );
}

export function BoxScore({ homeTeam, awayTeam }: BoxScoreProps) {
  const hasOT =
    (homeTeam.linescores?.length || 0) > 4 ||
    (awayTeam.linescores?.length || 0) > 4;

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-32">Team</TableHead>
          <TableHead className="text-center">Q1</TableHead>
          <TableHead className="text-center">Q2</TableHead>
          <TableHead className="text-center">Q3</TableHead>
          <TableHead className="text-center">Q4</TableHead>
          {hasOT && <TableHead className="text-center">OT</TableHead>}
          <TableHead className="text-center font-bold">T</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        <TeamScoreRow
          gameTeam={awayTeam}
          isWinner={awayTeam.isWinner ?? false}
        />
        <TeamScoreRow
          gameTeam={homeTeam}
          isWinner={homeTeam.isWinner ?? false}
        />
      </TableBody>
    </Table>
  );
}
