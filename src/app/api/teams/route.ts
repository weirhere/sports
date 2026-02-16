import { NextResponse } from "next/server";
import { MOCK_TEAMS } from "@/lib/mock";

export async function GET() {
  try {
    return NextResponse.json(MOCK_TEAMS);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch teams" },
      { status: 500 }
    );
  }
}
