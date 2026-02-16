import { NextRequest, NextResponse } from "next/server";
import { getGameDetail } from "@/lib/mock";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;

  try {
    const detail = getGameDetail(gameId);
    if (!detail) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    return NextResponse.json(detail);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch game detail" },
      { status: 500 }
    );
  }
}
