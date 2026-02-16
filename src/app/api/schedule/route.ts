import { NextRequest, NextResponse } from "next/server";
import { getGamesByWeek } from "@/lib/mock";
import { getScoreboard } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";
import { CURRENT_SEASON_YEAR } from "@/lib/constants";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const weekParam = searchParams.get("week");
  const yearParam = searchParams.get("year");
  const week = weekParam ? Number(weekParam) : 8;
  const year = yearParam ? Number(yearParam) : CURRENT_SEASON_YEAR;

  try {
    if (useEspnApi()) {
      const result = await getScoreboard({ week, year });
      return NextResponse.json(result);
    }

    const games = getGamesByWeek(week);
    return NextResponse.json({ games, week });
  } catch (err) {
    console.error("Schedule fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch schedule" },
      { status: 500 }
    );
  }
}
