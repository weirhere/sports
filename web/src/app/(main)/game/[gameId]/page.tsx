// The game-detail page: the server component fetches the summary straight
// from the provider (no HTTP hop) — real ESPN event ids only; an unknown
// or failed id is a 404. Standings ride along for the matchup card
// (Promise.allSettled — a miss just hides the card, never errors the page).

import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { gameSummary, conferenceStandings } from "@/lib/espn/provider";
import type { ConferenceStandingsGroup } from "@/lib/types";
import { GameDetailView } from "./game-detail-view";
import { ogCardModel } from "./og-card";

interface GameDetailPageProps {
  params: Promise<{ gameId: string }>;
}

export async function generateMetadata({
  params,
}: GameDetailPageProps): Promise<Metadata> {
  const { gameId } = await params;
  try {
    // Next memoizes the underlying fetch, so the page's own call reuses it.
    const detail = await gameSummary(gameId);
    const card = ogCardModel(detail.game);
    // The og: fields carry the same sentence the app's share text does, so
    // an unfurled link and a pasted share say the same thing. The image
    // itself is wired by the `opengraph-image` file convention beside this
    // one — Next resolves it against `metadataBase`.
    return {
      title: `${card.title} | StatSide`,
      description: card.description,
      openGraph: {
        type: "website",
        title: card.title,
        description: card.description,
        url: `/game/${gameId}`,
      },
      // X reads `og:image` when there's no twitter:image, but it needs the
      // card type or it renders a thumbnail instead of the full graphic.
      twitter: {
        card: "summary_large_image",
        title: card.title,
        description: card.description,
      },
    };
  } catch {
    return { title: "Game | StatSide" };
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
