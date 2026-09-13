// The H2H tab's endpoint.
//
// Behind a route rather than fetched with the page, which is the one place
// this port departs from iOS's shape and for iOS's own reason: a series is a
// season-by-season walk — 20 upstream requests for college football — and the
// game page is a server component, so an eager series would spend them on
// every render including the visits nobody opens the tab on. iOS spends them
// on an explicit tap; so does this.
//
// The anchor is re-read from the summary rather than trusted from the client:
// the tally's rules all key off the two team ids and the kickoff, and those
// are the page's facts, not a caller's. It costs nothing — the page just
// fetched the same summary, and Next's fetch cache hands back the same bytes.

import { NextRequest, NextResponse } from "next/server";
import {
  gameSummary,
  headToHead,
  EspnApiError,
  EspnDataError,
} from "@/lib/espn/provider";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;
  // Event ids are per-league: a summary fetched from the wrong league's base
  // URL 404s, so the league rides the request rather than being guessed.
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }

  try {
    const detail = await gameSummary(league, gameId);
    const series = await headToHead(league, detail.game);
    return NextResponse.json(series);
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    // An empty series and a broken one look identical on screen, and only one
    // of them gets to say "no meetings" — so a walk that fetched nothing is an
    // error here rather than a series with no meetings in it.
    if (err instanceof EspnDataError) {
      return NextResponse.json({ error: "No series data" }, { status: 502 });
    }
    console.error("Head-to-head fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch the series" },
      { status: 502 }
    );
  }
}
