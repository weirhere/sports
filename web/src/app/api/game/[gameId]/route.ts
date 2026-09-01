import { NextRequest, NextResponse } from "next/server";
import { getGameDetail } from "@/lib/mock";
import { getGameSummary } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;

  try {
    if (useEspnApi()) {
      const detail = await getGameSummary(gameId);
      return NextResponse.json(detail);
    }

    const detail = getGameDetail(gameId);
    if (!detail) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    return NextResponse.json(detail);
  } catch (err) {
    console.error("Game detail fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch game detail" },
      { status: 500 }
    );
  }
}
