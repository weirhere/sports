import { NextRequest, NextResponse } from "next/server";
import { scoreboard } from "@/lib/espn";

function numberParam(value: string | null): number | undefined {
  if (value === null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);

  try {
    const board = await scoreboard({
      weekValue: numberParam(searchParams.get("week")),
      seasonType: numberParam(searchParams.get("seasontype")),
      year: numberParam(searchParams.get("year")),
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
