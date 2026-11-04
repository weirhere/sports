// The game page's Standings tab endpoint (iOS `GameStandingsModel`,
// 2026-10-24).
//
// Behind a route for H2H's reason: the page is a server component, and the
// tab's tables — a pro league's conference and divisional responses, or
// each side's college-football division — would otherwise be spent on every
// render, including the visits nobody opens the tab on. Fetched once on the
// tab's first open, never polled.
//
// The season is re-read from the summary rather than trusted from the
// client: a past game's page reads that season's tables, membership
// included, and the kickoff is the page's fact, not a caller's.

import { NextRequest, NextResponse } from "next/server";
import { gameSummary, hubStandings, EspnApiError } from "@/lib/espn/provider";
import {
  collegeDivision,
  divisionGroupId,
  type CollegeDivision,
} from "@/lib/conferences";
import { hasCollegeDivisions, parseLeague, seasonYear } from "@/lib/leagues";
import type { GameStandings } from "@/lib/types";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ gameId: string }> }
) {
  const { gameId } = await params;
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }

  try {
    const { game } = await gameSummary(league, gameId);
    const year =
      game.scheduledAt !== ""
        ? seasonYear(league, new Date(game.scheduledAt))
        : seasonYear(league);
    // Undefined for the current season keeps the shipped request shape,
    // and with it the cache the team and conference pages share.
    const asked = year === seasonYear(league) ? undefined : year;

    // College football's standings come one division at a time, so an FCS
    // visitor needs FCS's tables beside FBS's. Everyone else answers the
    // whole league in one call (two, for the pros' divisional response).
    const divisions: (CollegeDivision | undefined)[] = hasCollegeDivisions(league)
      ? [
          ...new Set(
            [game.awayTeam.team, game.homeTeam.team].map(
              (team) => collegeDivision(Number(team.conferenceId), league) ?? "FBS"
            )
          ),
        ].sort()
      : [undefined];
    const settled = await Promise.allSettled(
      divisions.map((division) =>
        hubStandings(league, {
          year: asked,
          group: division ? divisionGroupId(division) : undefined,
        })
      )
    );
    const answered = settled.filter(
      (result) => result.status === "fulfilled"
    );
    if (answered.length === 0) {
      return NextResponse.json(
        { error: "Failed to fetch standings" },
        { status: 502 }
      );
    }
    const body: GameStandings = {
      year,
      groups: answered.flatMap((result) => result.value),
    };
    return NextResponse.json(body);
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Game not found" }, { status: 404 });
    }
    console.error("Game standings fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch standings" },
      { status: 502 }
    );
  }
}
