import { NextResponse } from "next/server";
import { MOCK_PLAYERS } from "@/lib/mock";

export async function GET() {
  try {
    return NextResponse.json(MOCK_PLAYERS);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch players" },
      { status: 500 }
    );
  }
}
