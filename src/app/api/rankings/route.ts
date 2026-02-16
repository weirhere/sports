import { NextResponse } from "next/server";
import { getRankings } from "@/lib/mock";

export async function GET() {
  try {
    const rankings = getRankings();
    return NextResponse.json(rankings);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch rankings" },
      { status: 500 }
    );
  }
}
