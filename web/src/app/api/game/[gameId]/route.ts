// Thin handler over the provider's game summary — the client polling
// hook's endpoint. A bad or unknown event id is a 404; an ESPN outage is a
// 502, never a crash.

import { NextRequest, NextResponse } from "next/server";
import { gameSummary, EspnApiError, EspnDataError } from "@/lib/espn/provider";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;

  try {
    const detail = await gameSummary(gameId);
    return NextResponse.json(detail);
  } catch (err) {
    if (
      err instanceof EspnDataError ||
      (err instanceof EspnApiError && err.status < 500)
    ) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    console.error("Game detail fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch game detail" },
      { status: 502 }
    );
  }
}
