// The player page's Games tab endpoint.
//
// Behind a route for the trophy case's reason: the page is server-rendered
// and most visits never open Games, so the log is paid for on the tab's
// first appearance rather than with every page view — iOS `PlayerStatsModel`
// waits for the tab the same way. Each season is its own request, since the
// season chip asks for one at a time.

import { NextRequest, NextResponse } from "next/server";
import { athleteGameLog } from "@/lib/espn/athlete";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ athleteId: string }> }
) {
  const { athleteId } = await params;
  const query = new URL(request.url).searchParams;
  // Athlete ids repeat across leagues, so the league rides the request
  // rather than being guessed from the id.
  const league = parseLeague(query.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  if (!/^\d+$/.test(athleteId)) {
    return NextResponse.json({ error: "Unknown athlete" }, { status: 400 });
  }
  // ESPN's own season numbering — the chip converts at its edge. Absent
  // means whatever ESPN calls current.
  const rawSeason = query.get("season");
  if (rawSeason !== null && !/^\d{4}$/.test(rawSeason)) {
    return NextResponse.json({ error: "Unknown season" }, { status: 400 });
  }

  try {
    const log = await athleteGameLog(
      league,
      athleteId,
      rawSeason === null ? undefined : Number(rawSeason)
    );
    return NextResponse.json(log);
  } catch (err) {
    console.error("Game log fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch the game log" },
      { status: 502 }
    );
  }
}
