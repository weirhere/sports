// The game-detail page: the server component fetches the summary straight
// from the provider (no HTTP hop) — real ESPN event ids only; an unknown
// or failed id is a 404. Standings ride along for the matchup card
// (Promise.allSettled — a miss just hides the card, never errors the page).

import { notFound } from "next/navigation";
import { gameSummary, conferenceStandings } from "@/lib/espn/provider";
import type { ConferenceStandingsGroup } from "@/lib/types";
import { GameDetailView } from "./game-detail-view";

interface GameDetailPageProps {
  params: Promise<{ gameId: string }>;
}

export async function generateMetadata({ params }: GameDetailPageProps) {
  const { gameId } = await params;
  try {
    // Next memoizes the underlying fetch, so the page's own call reuses it.
    const detail = await gameSummary(gameId);
    const away = detail.game.awayTeam.team.school;
    const home = detail.game.homeTeam.team.school;
    return { title: `${away} at ${home} | College Football Hub` };
  } catch {
    return { title: "Game | College Football Hub" };
  }
}

export default async function GameDetailPage({ params }: GameDetailPageProps) {
  const { gameId } = await params;
  if (!/^\d+$/.test(gameId)) {
    notFound();
  }

  const [detailResult, standingsResult] = await Promise.allSettled([
    gameSummary(gameId),
    conferenceStandings(),
  ]);
  if (detailResult.status !== "fulfilled") {
    notFound();
  }
  const standings: ConferenceStandingsGroup[] | null =
    standingsResult.status === "fulfilled" ? standingsResult.value : null;

  return (
    <GameDetailView initialData={detailResult.value} standings={standings} />
  );
}
