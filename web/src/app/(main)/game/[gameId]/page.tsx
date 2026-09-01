import { notFound } from "next/navigation";
import { getGameDetail } from "@/lib/mock/game-detail";
import { GameDetailView } from "./game-detail-view";

export function generateMetadata() {
  return { title: "Game Detail | College Football Hub" };
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

  return <GameDetailView initialData={detail} />;
}
