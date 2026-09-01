import { notFound } from "next/navigation";
import { getTeamById, getGamesByTeam } from "@/lib/mock";
import { TeamLogo } from "@/components/team-logo";
import { GameCard } from "@/components/game-card";
import { FavoriteButton } from "@/components/favorite-button";
import { EmptyState } from "@/components/empty-state";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { MOCK_TOP_25 } from "@/lib/mock/rankings";

export function generateMetadata() {
  return { title: "Team | College Football Hub" };
}

export default async function TeamPage({
  params,
}: {
  params: Promise<{ teamId: string }>;
}) {
  const { teamId } = await params;
  const team = getTeamById(teamId);

  if (!team) {
    notFound();
  }

  const games = getGamesByTeam(teamId);
  const ranking = MOCK_TOP_25.find((r) => r.team.id === teamId);

  const upcomingGames = games.filter((g) => g.status === "scheduled");
  const completedGames = games.filter(
    (g) => g.status === "complete" || g.status === "in_progress"
  );

  return (
    <div>
      {/* Team Header */}
      <div className="mb-6 flex items-center gap-4">
        <TeamLogo
          espnId={team.espnId}
          teamName={team.school}
          size="xl"
        />
        <div>
          <div className="flex items-center gap-2">
            {ranking && (
              <Badge variant="secondary" className="font-score">
                #{ranking.rank}
              </Badge>
            )}
            <h1 className="text-2xl font-bold">{team.school}</h1>
            <FavoriteButton teamId={team.id} />
          </div>
          <p className="text-sm text-muted-foreground">
            {team.name} &middot; {team.conferenceName}
          </p>
          {ranking && (
            <p className="mt-1 text-sm text-muted-foreground">
              {ranking.record}
            </p>
          )}
        </div>
      </div>

      {/* Tabs */}
      <Tabs defaultValue="schedule" className="w-full">
        <TabsList className="mb-4">
          <TabsTrigger value="schedule">Schedule</TabsTrigger>
          <TabsTrigger value="results">Results</TabsTrigger>
        </TabsList>

        <TabsContent value="schedule">
          {upcomingGames.length > 0 ? (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {upcomingGames.map((game) => (
                <GameCard key={game.id} game={game} />
              ))}
            </div>
          ) : (
            <EmptyState
              title="No upcoming games"
              description="There are no scheduled games for this team."
            />
          )}
        </TabsContent>

        <TabsContent value="results">
          {completedGames.length > 0 ? (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {completedGames.map((game) => (
                <GameCard key={game.id} game={game} />
              ))}
            </div>
          ) : (
            <EmptyState
              title="No results yet"
              description="No games have been completed for this team."
            />
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
