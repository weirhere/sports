// The Trophies tab's endpoint.
//
// Behind a route for the H2H series' reason, doubled: a trophy case is every
// season at once — a dozen of them, two requests each — and the team page is
// server-rendered per season. Fanning that out on every page view would make
// the schedule tab pay for a tab most visits never open. Paid on the tab's
// first appearance instead, and each season's pair is held in Next's fetch
// cache for an hour across every visitor.

import { NextRequest, NextResponse } from "next/server";
import {
  teamTrophyCase,
  EspnApiError,
  EspnDataError,
} from "@/lib/espn/provider";
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
    const shelf = await teamTrophyCase(league, teamId);
    return NextResponse.json(shelf);
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Team not found" }, { status: 404 });
    }
    // A team that has won nothing and a network that answered nothing look
    // identical on the tab, and only one of them is worth a Retry button — so
    // a walk that fetched no season at all fails rather than returning an
    // empty shelf.
    if (err instanceof EspnDataError) {
      return NextResponse.json({ error: "No seasons fetched" }, { status: 502 });
    }
    console.error("Trophy case fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch the trophy case" },
      { status: 502 }
    );
  }
}
