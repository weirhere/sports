// The News tab's league pages (iOS E26): one league's feed, previews last.
// Held in Next's fetch cache for five minutes across every visitor.

import { NextRequest, NextResponse } from "next/server";
import { leagueNews } from "@/lib/espn/news-provider";
import { parseLeague } from "@/lib/leagues";

export async function GET(request: NextRequest) {
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  try {
    return NextResponse.json(await leagueNews(league));
  } catch (err) {
    console.error("League news fetch error:", err);
    return NextResponse.json({ error: "Failed to fetch the news" }, { status: 502 });
  }
}
