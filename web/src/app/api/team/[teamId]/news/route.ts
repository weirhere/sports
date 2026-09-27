// The team page's News tab endpoint (iOS E25, docs/news.md N9).
//
// Behind a route for the Trophies tab's reason: the team page is
// server-rendered, and a feed most visits never open shouldn't hold up its
// first byte. Paid on the tab's first appearance instead, and held in
// Next's fetch cache for five minutes across every visitor.

import { NextRequest, NextResponse } from "next/server";
import { EspnApiError } from "@/lib/espn/provider";
import { teamNews } from "@/lib/espn/news-provider";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ teamId: string }> }
) {
  const { teamId } = await params;
  // Team ids collide across leagues (5 is UAB and the Browns), so the league
  // rides the request rather than being guessed from the id.
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  if (!/^\d+$/.test(teamId)) {
    return NextResponse.json({ error: "Unknown team" }, { status: 400 });
  }

  try {
    return NextResponse.json(await teamNews(league, teamId));
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Team not found" }, { status: 404 });
    }
    // A team with no stories and a feed that didn't answer look identical on
    // the tab, and only one of them is worth a Retry button.
    console.error("Team news fetch error:", err);
    return NextResponse.json({ error: "Failed to fetch the news" }, { status: 502 });
  }
}
