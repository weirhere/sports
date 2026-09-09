// Thin handler over the provider's game summary — the client polling
// hook's endpoint. A bad or unknown event id is a 404; an ESPN outage is a
// 502, never a crash.

import { NextRequest, NextResponse } from "next/server";
import { gameSummary, EspnApiError, EspnDataError } from "@/lib/espn/provider";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;
  // Event ids are per-league: a summary fetched from the wrong league's
  // base URL 404s, so the league rides the request rather than being
  // guessed from the id.
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }

  try {
    const detail = await gameSummary(league, gameId);
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
