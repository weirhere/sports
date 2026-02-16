import Link from "next/link";
import type { ConferenceStanding } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface StandingsTableProps {
  standings: ConferenceStanding[];
}

export function StandingsTable({ standings }: StandingsTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-10">#</TableHead>
          <TableHead>Team</TableHead>
          <TableHead className="text-center">Conf</TableHead>
          <TableHead className="text-center">Overall</TableHead>
          <TableHead className="hidden text-center sm:table-cell">
            Streak
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {standings.map((s) => (
          <TableRow key={s.team.id}>
            <TableCell className="font-score text-muted-foreground">
              {s.conferenceRank}
            </TableCell>
            <TableCell>
              <Link
                href={`/team/${s.team.id}`}
                className="flex items-center gap-2 hover:underline"
              >
                <TeamLogo
                  espnId={s.team.espnId}
                  teamName={s.team.school}
                  size="sm"
                />
                <span className="text-sm font-medium">{s.team.school}</span>
              </Link>
            </TableCell>
            <TableCell className="font-score text-center text-sm">
              {s.conferenceWins}-{s.conferenceLosses}
            </TableCell>
            <TableCell className="font-score text-center text-sm">
              {s.overallWins}-{s.overallLosses}
            </TableCell>
            <TableCell className="hidden text-center text-sm sm:table-cell">
              {s.streakType && s.streakLength ? (
                <span
                  className={
                    s.streakType === "W"
                      ? "text-green-600 dark:text-green-400"
                      : "text-red-600 dark:text-red-400"
                  }
                >
                  {s.streakType}
                  {s.streakLength}
                </span>
              ) : (
                "-"
              )}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
