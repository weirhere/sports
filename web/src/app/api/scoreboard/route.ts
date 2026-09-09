// Thin handler over the provider's scoreboard.
//
// `league` is required and validated: it selects the ESPN base URL, and a
// league we don't know would otherwise build a URL for a sport that doesn't
// exist. Either a week (`week` + `seasontype`) or a day window (`start` +
// `end`, as `YYYY-MM-DD`) — the day window is what the Scores screen asks
// for, the week is what a football league's own pages still use.

import { NextRequest, NextResponse } from "next/server";
import { scoreboard, scoreboardForDays } from "@/lib/espn";
import { parseLeague } from "@/lib/leagues";

function numberParam(value: string | null): number | undefined {
  if (value === null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

/** `YYYY-MM-DD` as a *local* midnight — the day axis is the viewer's. */
function dayParam(value: string | null): Date | undefined {
  if (value === null) return undefined;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return undefined;
  const date = new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3])
  );
  return Number.isNaN(date.getTime()) ? undefined : date;
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const league = parseLeague(searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }

  const start = dayParam(searchParams.get("start"));
  const end = dayParam(searchParams.get("end"));
  const groups = numberParam(searchParams.get("groups"));

  try {
    const board =
      start && end
        ? await scoreboardForDays(league, start, end, { groups })
        : await scoreboard(league, {
            weekValue: numberParam(searchParams.get("week")),
            seasonType: numberParam(searchParams.get("seasontype")),
            year: numberParam(searchParams.get("year")),
            groups,
          });
    return NextResponse.json(board);
  } catch (err) {
    console.error("Scoreboard fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch scoreboard" },
      { status: 502 }
    );
  }
}
