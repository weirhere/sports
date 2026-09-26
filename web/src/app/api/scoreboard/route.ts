// Thin handler over the provider's scoreboard.
//
// `league` is required and validated: it selects the ESPN base URL, and a
// league we don't know would otherwise build a URL for a sport that doesn't
// exist. Either a week (`week` + `seasontype`), a day window (`start` +
// `end`, as `YYYY-MM-DD`), or ESPN's own day tokens (`dates`, comma
// separated `YYYYMMDD`). The day window is what the Scores screen asks for,
// `dates` is its live poll, and the week is what a football league's own
// pages still use.

import { NextRequest, NextResponse } from "next/server";
import {
  EspnApiError,
  scoreboard,
  scoreboardForDateTokens,
  scoreboardForDays,
} from "@/lib/espn";
import { parseLeague } from "@/lib/leagues";
import { MAX_LIVE_DAY_TOKENS } from "@/lib/live-days";

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


/**
 * `20260925,20260926` as tokens; undefined if absent or malformed. Capped
 * at `MAX_LIVE_DAY_TOKENS`, so a hostile query can't fan out into a
 * request per token.
 */
function dateTokensParam(value: string | null): string[] | undefined {
  if (value === null) return undefined;
  const tokens = value.split(",");
  if (tokens.length === 0 || tokens.length > MAX_LIVE_DAY_TOKENS) return undefined;
  return tokens.every((token) => /^\d{8}$/.test(token)) ? tokens : undefined;
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

  const datesValue = searchParams.get("dates");
  const dates = dateTokensParam(datesValue);
  if (datesValue !== null && !dates) {
    return NextResponse.json({ error: "Bad dates" }, { status: 400 });
  }

  try {
    if (dates) {
      const games = await scoreboardForDateTokens(league, dates, { groups });
      return NextResponse.json({ league, games });
    }
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
    // Forward ESPN's own status, so the browser can say *which* failure it
    // was rather than a flat "couldn't reach". The response stays a 502:
    // the upstream status describes ESPN's answer, not ours.
    return NextResponse.json(
      {
        error: "Failed to fetch scoreboard",
        upstreamStatus: err instanceof EspnApiError ? err.status : undefined,
      },
      { status: 502 }
    );
  }
}
