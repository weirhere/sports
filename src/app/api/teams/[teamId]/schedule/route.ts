import { NextRequest, NextResponse } from "next/server";
import { getGamesByTeam } from "@/lib/mock";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ teamId: string }> }
) {
  const { teamId } = await params;

  try {
    const games = getGamesByTeam(teamId);
    return NextResponse.json(games);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch team schedule" },
      { status: 500 }
    );
  }
}
