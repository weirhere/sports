import { notFound } from "next/navigation";
import Link from "next/link";
import { getGameDetail } from "@/lib/mock/game-detail";
import { TeamLogo } from "@/components/team-logo";
import { ScoreDisplay } from "@/components/score-display";
import { LiveIndicator } from "@/components/live-indicator";
import { BoxScore } from "@/components/box-score";
import { DriveSummary } from "@/components/drive-summary";
import { PlayByPlay } from "@/components/play-by-play";
import { TeamStatsComparison } from "@/components/team-stats-comparison";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

export function generateMetadata() {
  return { title: "Game Detail | College Football Hub" };
}

function isLive(status: string) {
  return (
    status === "in_progress" ||
    status === "halftime" ||
    status === "end_period"
  );
}

function getStatusLabel(game: NonNullable<ReturnType<typeof getGameDetail>>["game"]) {
  if (game.status === "complete") return "Final";
  if (game.status === "halftime") return "Halftime";
  if (isLive(game.status)) {
    const q = game.quarter && game.quarter > 4 ? "OT" : `Q${game.quarter}`;
    return `${q} ${game.clock || ""}`.trim();
  }
  return new Date(game.scheduledAt).toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export default async function GameDetailPage({
  params,
}: {
  params: Promise<{ gameId: string }>;
}) {
  const { gameId } = await params;
  const detail = getGameDetail(gameId);

  if (!detail) {
    notFound();
  }

  const { game, boxScore, plays, homeStats, awayStats } = detail;
  const live = isLive(game.status);

  return (
    <div>
      {/* Game Header */}
      <div className="mb-6 rounded-lg border bg-card p-6">
        <div className="flex flex-col items-center gap-6 sm:flex-row sm:justify-center sm:gap-12">
          {/* Away team */}
          <Link
            href={`/team/${game.awayTeam.team.id}`}
            className="flex flex-col items-center gap-2 text-center hover:opacity-80"
          >
            <TeamLogo
              espnId={game.awayTeam.team.espnId}
              teamName={game.awayTeam.team.school}
              size="xl"
            />
            <div>
              {game.awayTeam.ranking && (
                <span className="text-xs font-medium text-muted-foreground">
                  #{game.awayTeam.ranking}{" "}
                </span>
              )}
              <span className="text-base font-semibold">
                {game.awayTeam.team.school}
              </span>
            </div>
            {game.awayTeam.record && (
              <span className="text-xs text-muted-foreground">
                {game.awayTeam.record}
              </span>
            )}
          </Link>

          {/* Score / Status */}
          <div className="flex flex-col items-center gap-1">
            {game.status !== "scheduled" ? (
              <div className="flex items-center gap-4">
                <span
                  className={cn(
                    "font-score text-4xl",
                    game.awayTeam.isWinner ? "font-bold" : "text-muted-foreground"
                  )}
                >
                  {game.awayTeam.score}
                </span>
                <span className="text-lg text-muted-foreground">-</span>
                <span
                  className={cn(
                    "font-score text-4xl",
                    game.homeTeam.isWinner ? "font-bold" : "text-muted-foreground"
                  )}
                >
                  {game.homeTeam.score}
                </span>
              </div>
            ) : null}

            <div className="mt-1">
              {live ? (
                <LiveIndicator />
              ) : (
                <span className="text-sm text-muted-foreground">
                  {getStatusLabel(game)}
                </span>
              )}
            </div>

            {game.broadcast && (
              <span className="text-xs text-muted-foreground">
                {game.broadcast}
              </span>
            )}

            {game.venue && (
              <span className="text-xs text-muted-foreground">
                {game.venue.name} - {game.venue.city}, {game.venue.state}
              </span>
            )}
          </div>

          {/* Home team */}
          <Link
            href={`/team/${game.homeTeam.team.id}`}
            className="flex flex-col items-center gap-2 text-center hover:opacity-80"
          >
            <TeamLogo
              espnId={game.homeTeam.team.espnId}
              teamName={game.homeTeam.team.school}
              size="xl"
            />
            <div>
              {game.homeTeam.ranking && (
                <span className="text-xs font-medium text-muted-foreground">
                  #{game.homeTeam.ranking}{" "}
                </span>
              )}
              <span className="text-base font-semibold">
                {game.homeTeam.team.school}
              </span>
            </div>
            {game.homeTeam.record && (
              <span className="text-xs text-muted-foreground">
                {game.homeTeam.record}
              </span>
            )}
          </Link>
        </div>
      </div>

      {/* Detail Tabs */}
      <Tabs defaultValue="boxscore" className="w-full">
        <TabsList className="mb-4 w-full sm:w-auto">
          <TabsTrigger value="boxscore" className="flex-1 sm:flex-none">
            Box Score
          </TabsTrigger>
          <TabsTrigger value="plays" className="flex-1 sm:flex-none">
            Play-by-Play
          </TabsTrigger>
          <TabsTrigger value="stats" className="flex-1 sm:flex-none">
            Team Stats
          </TabsTrigger>
        </TabsList>

        <TabsContent value="boxscore" className="space-y-6">
          <BoxScore homeTeam={game.homeTeam} awayTeam={game.awayTeam} />
          <div>
            <h3 className="mb-3 text-base font-semibold">Scoring Drives</h3>
            <DriveSummary
              drives={boxScore.scoringDrives}
              homeTeam={game.homeTeam}
              awayTeam={game.awayTeam}
            />
          </div>
        </TabsContent>

        <TabsContent value="plays">
          <PlayByPlay
            plays={plays}
            homeTeam={game.homeTeam}
            awayTeam={game.awayTeam}
          />
        </TabsContent>

        <TabsContent value="stats">
          <TeamStatsComparison
            homeStats={homeStats}
            awayStats={awayStats}
            homeTeam={game.homeTeam}
            awayTeam={game.awayTeam}
          />
        </TabsContent>
      </Tabs>
    </div>
  );
}
