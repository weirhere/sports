// The player page's News tab endpoint (iOS E26): the athlete overview's own
// list of stories, fetched on the tab's first open — the game log's rule.

import { NextRequest, NextResponse } from "next/server";
import { playerNews } from "@/lib/espn/news-provider";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ athleteId: string }> }
) {
  const { athleteId } = await params;
  // Athlete ids repeat across leagues, so the league rides the request.
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  if (!/^\d+$/.test(athleteId)) {
    return NextResponse.json({ error: "Unknown athlete" }, { status: 400 });
  }
  try {
    return NextResponse.json(await playerNews(league, athleteId));
  } catch (err) {
    console.error("Player news fetch error:", err);
    return NextResponse.json({ error: "Failed to fetch the news" }, { status: 502 });
  }
}
