// The Roster tab's endpoint (E29, 2026-10-18).
//
// Behind a route rather than fetched with the page, for the H2H tab's
// reason: six upstream requests is a lot to spend on a tab most visits never
// open, and the game page is a server component that would spend them on
// every render. iOS spends them on an explicit tap; so does this.
//
// The anchor is re-read from the summary rather than trusted from the
// client: which teams, which phase and whether this is the current season
// are the page's facts, not a caller's. It costs nothing — the page just
// fetched the same summary, and Next's fetch cache hands back the same
// bytes. The route serves the *sources* and the client assembles them
// against the summary it already holds, so the bench follows the box
// score's poll without a second request.

import { NextRequest, NextResponse } from "next/server";
import {
  gameSummary,
  gameRosterSources,
  EspnApiError,
  EspnDataError,
} from "@/lib/espn/provider";
import { parseLeague, seasonYear } from "@/lib/leagues";
import { rosterPhase } from "@/lib/game-roster";

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
    const { game } = detail;
    // Past-season games can't be asked for a roster: ESPN's `/roster` has
    // no season axis and answers with today's squad, which would list this
    // year's team as having played a game from years ago. Read on this
    // league's own clock.
    const currentSeason =
      game.scheduledAt !== "" &&
      seasonYear(league, new Date(game.scheduledAt)) === seasonYear(league);
    const sources = await gameRosterSources(league, game, {
      phase: rosterPhase(game.status),
      currentSeason,
    });
    return NextResponse.json(sources);
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    // Every source failed. An empty roster and a broken one look identical
    // on screen, and only one of them gets to say "Lineups TBA" — so a
    // fetch that got nothing is an error here, which is what offers Retry.
    if (err instanceof EspnDataError) {
      return NextResponse.json({ error: "No roster data" }, { status: 502 });
    }
    console.error("Game roster fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch the roster" },
      { status: 502 }
    );
  }
}
