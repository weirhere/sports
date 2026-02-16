import { notFound } from "next/navigation";
import { getConferenceById, ALL_CONFERENCES } from "@/config/conferences";
import { getStandings } from "@/lib/mock/standings";
import { MOCK_GAMES } from "@/lib/mock/games";
import { StandingsTable } from "@/components/standings-table";
import { GameCard } from "@/components/game-card";
import { EmptyState } from "@/components/empty-state";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { FavoriteButton } from "@/components/favorite-button";

export function generateMetadata({
  params,
}: {
  params: Promise<{ conferenceId: string }>;
}) {
  // Can't await in generateMetadata synchronously with our static data,
  // but we can return a basic title
  return {
    title: "Conference | College Football Hub",
  };
}

export default async function ConferenceDetailPage({
  params,
}: {
  params: Promise<{ conferenceId: string }>;
}) {
  const { conferenceId } = await params;
  const conference = getConferenceById(conferenceId);

  if (!conference) {
    notFound();
  }

  const standings = getStandings(conferenceId);

  // Get games involving teams from this conference
  const conferenceGames = MOCK_GAMES.filter(
    (g) =>
      g.homeTeam.team.conferenceId === conferenceId ||
      g.awayTeam.team.conferenceId === conferenceId
  );

  const upcomingGames = conferenceGames.filter(
    (g) => g.status === "scheduled"
  );
  const completedGames = conferenceGames.filter(
    (g) => g.status === "complete"
  );

  return (
    <div>
      <div className="mb-6 flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold">{conference.name}</h1>
          <p className="text-sm text-muted-foreground">{conference.division}</p>
        </div>
        <FavoriteButton teamId={conferenceId} type="conference" />
      </div>

      <Tabs defaultValue="standings" className="w-full">
        <TabsList className="mb-4">
          <TabsTrigger value="standings">Standings</TabsTrigger>
          <TabsTrigger value="schedule">Schedule</TabsTrigger>
          <TabsTrigger value="results">Results</TabsTrigger>
        </TabsList>

        <TabsContent value="standings">
          {standings.length > 0 ? (
            <StandingsTable standings={standings} />
          ) : (
            <EmptyState
              title="No standings available"
              description="Standings data is not yet available for this conference."
            />
          )}
        </TabsContent>

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
              description="There are no scheduled games for this conference."
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
              description="No games have been completed for this conference."
            />
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
