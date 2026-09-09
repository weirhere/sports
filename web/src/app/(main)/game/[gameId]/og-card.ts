// What a game's link preview says — every string in one pure function, so
// the unfurl's copy is testable without rendering a 1200×630 PNG.
//
// The card is the iOS share card's shape (`GameShareCardView.swift`): logos
// flanking a status column, records under the names, the kickoff time
// headlining a game that hasn't started. It is a re-implementation, not a
// port — SwiftUI can't cross the wire — so the two are kept in step by
// hand, and this file is the seam where that happens.
//
// One thing it deliberately does NOT share with the app: the timezone. The
// app renders a kickoff in the reader's own zone because it knows it; an
// OpenGraph image is rendered once on a server and then shown to everyone
// who sees the link, so it commits to Eastern and says so ("12:30 PM ET").
// A bare "5:30 PM" built from the server's UTC clock would be wrong for
// every reader including the sender.

import type { Game, GameTeam } from "@/lib/types";
import { isLiveStatus, showsScores, statusLine } from "./game-status";

/** The league's clock, and the only one a shared image can honestly use. */
const LEAGUE_TIME_ZONE = "America/New_York";

export interface OgCardSide {
  /** "#1 Ohio State" — the rank rides the name, as it does in the app. */
  name: string;
  record?: string;
  score: number | null;
  /**
   * Tri-state on purpose: true won, false lost, undefined not called yet.
   * The card mutes a loser's score, and "we don't know" must not read as
   * "lost" — a live game has no winner and neither side should dim.
   */
  isWinner?: boolean;
  logoUrl: string;
}

export interface OgCardModel {
  away: OgCardSide;
  home: OgCardSide;
  /** Pre-game shows no scores at all — no 0–0, no dashes. */
  showsScores: boolean;
  isLive: boolean;
  /**
   * Pre-game only: the kickoff split in two, the time headlining. Null for
   * every other status, which renders `status` instead.
   */
  kickoff: { time: string; date: string } | null;
  /** The one-line status for a game that is under way or done. */
  status: string | null;
  /** The network, pre-game and live — a final has nothing left to watch. */
  broadcast?: string;
  /** og:title — the matchup, or the score once there is one. */
  title: string;
  /** og:description — when, where, and on what. */
  description: string;
  /** The image's alt text, for readers whose client shows it. */
  alt: string;
}

/** "Sat, Sep 5", on the league's clock. */
export function easternDayText(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    timeZone: LEAGUE_TIME_ZONE,
  });
}

/** "12:30 PM ET" — the zone is named because the reader's may differ. */
export function easternTimeText(iso: string): string {
  const time = new Date(iso).toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZone: LEAGUE_TIME_ZONE,
  });
  return `${time} ET`;
}

function sideName(side: GameTeam): string {
  return side.ranking ? `#${side.ranking} ${side.team.school}` : side.team.school;
}

function side(team: GameTeam): OgCardSide {
  return {
    name: sideName(team),
    record: team.record,
    score: team.score,
    isWinner: team.isWinner,
    logoUrl: team.team.logoUrl,
  };
}

function scored(team: GameTeam): string {
  return `${sideName(team)} ${team.score ?? "–"}`;
}

function venueText(game: Game): string | undefined {
  const { name, city, state } = game.venue ?? {};
  if (!name) return undefined;
  const where = [city, state].filter(Boolean).join(", ");
  return where ? `${name}, ${where}` : name;
}

export function ogCardModel(game: Game): OgCardModel {
  const isPre = game.status === "scheduled";
  const live = isLiveStatus(game.status);
  const kickoff = isPre
    ? {
        time: game.timeTBD ? "TBD" : easternTimeText(game.scheduledAt),
        date: easternDayText(game.scheduledAt),
      }
    : null;
  const broadcast = isPre || live ? game.broadcast : undefined;

  const matchup = `${sideName(game.awayTeam)} at ${sideName(game.homeTeam)}`;
  const scoreLine = `${scored(game.awayTeam)}, ${scored(game.homeTeam)}`;

  let title: string;
  let description: string;
  if (isPre) {
    title = matchup;
    // The kickoff leads: it is the one thing a pre-game link is opened for.
    const when = game.timeTBD
      ? `${kickoff!.date}, time TBD`
      : `${kickoff!.date} ${kickoff!.time}`;
    description = [when, broadcast && `on ${broadcast}`, venueText(game)]
      .filter(Boolean)
      .join(" · ");
  } else if (live) {
    title = scoreLine;
    description = [statusLine(game), broadcast && `on ${broadcast}`]
      .filter(Boolean)
      .join(" · ");
  } else if (game.status === "complete") {
    title = `Final: ${scoreLine}`;
    description = [easternDayText(game.scheduledAt), venueText(game)]
      .filter(Boolean)
      .join(" · ");
  } else {
    // Postponed, cancelled, delayed: the status IS the news.
    title = `${matchup} · ${statusLine(game)}`;
    description = [easternDayText(game.scheduledAt), venueText(game)]
      .filter(Boolean)
      .join(" · ");
  }

  return {
    away: side(game.awayTeam),
    home: side(game.homeTeam),
    showsScores: showsScores(game),
    isLive: live,
    kickoff,
    status: kickoff ? null : statusLine(game),
    broadcast,
    title,
    description,
    alt: `${title}${description ? `. ${description}` : ""}`,
  };
}
