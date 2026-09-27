// News, attached to games and teams — the web twin of iOS `NewsStory`,
// `StoryText` and `NewsTimestamp` (StatSideShared/Models/, E25,
// docs/news.md).
//
// Text only (N8): ESPN ships a photo with every story and none is read,
// because press photography isn't in the color budget. A story arrives two
// ways — the game summary's `article`, whole, and a team feed's headlines,
// whose text the reader fetches by id.

import type { League } from "./leagues";
import type { GameStatus } from "./types";
import { gameState } from "./game-state";

/** The ESPN story types the app shows (N10). `Media` is video that only
 *  plays in ESPN's own apps and `Eticket` is ticket commerce; neither maps. */
export type StoryKind = "recap" | "preview" | "headline" | "story";

const KINDS: Record<string, StoryKind> = {
  Recap: "recap",
  Preview: "preview",
  HeadlineNews: "headline",
  Story: "story",
};

export function storyKind(espnType: string | undefined): StoryKind | undefined {
  return espnType ? KINDS[espnType] : undefined;
}

/** The game page card's title, and the reader's eyebrow. */
export function storyKindTitle(kind: StoryKind): string {
  return kind === "recap" ? "Recap" : kind === "preview" ? "Preview" : "Story";
}

export type StoryBlock =
  | { kind: "heading"; text: string }
  | { kind: "paragraph"; text: string };

/** A team the story is tagged with. College programs are tagged twice (the
 *  team and the university) under one id, so tags are unique by id. */
export interface StoryTeamTag {
  id: string;
  name: string;
}

export interface NewsStory {
  id: string;
  kind: StoryKind;
  league: League;
  headline: string;
  /** ESPN's `description`: the dek under the headline. */
  dek?: string;
  /** A byline, else the wire ("AP"); absent when ESPN names neither. */
  attribution?: string;
  /** ISO 8601. */
  published?: string;
  /** The game the story is about, where ESPN says. */
  gameId?: string;
  teams: StoryTeamTag[];
  /** The text, where it rode along. A team feed's items have none. */
  body?: StoryBlock[];
}

/**
 * Whether the story is about `teamId` rather than a roundup that mentions
 * it (N9). ESPN's `team=` filter tags every result with the team, but most
 * are league-wide pieces tagged with a dozen more. Two teams or fewer is one
 * team's story or one game's. Probe, 2026-09-27: Michigan kept 6 of 25, the
 * Knicks 11 of 25.
 */
export function isFocused(story: NewsStory, teamId: string): boolean {
  return story.teams.length <= 2 && story.teams.some((team) => team.id === teamId);
}

/**
 * The story the game page shows, or undefined: the recap once final (N2),
 * the preview before kickoff (N3), nothing live. A story filed under
 * another game never shows.
 */
export function storyForGame(
  article: NewsStory | undefined,
  gameId: string,
  status: GameStatus
): NewsStory | undefined {
  if (!article || article.gameId !== gameId) return undefined;
  const state = gameState(status);
  if (article.kind === "recap" && state === "final") return article;
  if (article.kind === "preview" && state === "pre") return article;
  return undefined;
}

// --- Text ---

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“",
  mdash: "—", ndash: "–", hellip: "…",
};

/** HTML entities to characters; an unknown one is left as written. */
export function decodeEntities(text: string): string {
  return text.replace(/&(#[xX][0-9a-fA-F]+|#\d+|[a-zA-Z]+);/g, (match, name: string) => {
    if (name.startsWith("#")) {
      const hex = name[1] === "x" || name[1] === "X";
      const code = parseInt(name.slice(hex ? 2 : 1), hex ? 16 : 10);
      return Number.isFinite(code) && code <= 0x10ffff ? String.fromCodePoint(code) : match;
    }
    return NAMED_ENTITIES[name] ?? match;
  });
}

/**
 * ESPN's story HTML as headings and paragraphs in the app's own type (N4).
 *
 * Two dialects arrive: AP copy in the game summary, blank-line paragraphs
 * with `<hl2>` subheads; and ESPN's own stories from the content API,
 * `<p>` and `<h2>` with embeds between them. Links keep their words and lose
 * their targets. AP ends its story at a `------` rule, before its
 * boilerplate.
 */
export function storyBlocks(html: string): StoryBlock[] {
  let text = html.replace(
    /<\s*(h[1-6]|hl[1-6])\b[^>]*>([\s\S]*?)<\s*\/\s*\1\s*>/gi,
    "\n\n\u0001$2\n\n"
  );
  text = text.replace(/<\s*\/?\s*(p|div|br|hr|li|ul|ol|blockquote)\b[^>]*>/gi, "\n\n");
  text = text.replace(/<[^>]*>/g, "");

  const blocks: StoryBlock[] = [];
  for (const raw of text.split("\n\n")) {
    const line = decodeEntities(raw).split(/\s+/).filter(Boolean).join(" ");
    if (!line) continue;
    if (/^-+$/.test(line)) break;
    if (line.startsWith("\u0001")) {
      const heading = line.slice(1).trim();
      if (heading) blocks.push({ kind: "heading", text: heading });
    } else {
      // AP's dateline arrives as "NEW YORK -- — …": the wire's double
      // hyphen and ESPN's dash, both. One dash is the dateline.
      blocks.push({ kind: "paragraph", text: line.replace(" -- — ", " — ") });
    }
  }
  return blocks;
}

/** A byline wins; else the wire, shortened where it has a short name. */
export function attribution(byline?: string, source?: string): string | undefined {
  const named = byline?.trim();
  if (named) return named;
  const wire = source?.trim();
  if (!wire) return undefined;
  return wire === "Associated Press" ? "AP" : wire;
}

// --- Time (N7) ---

function dayNumber(date: Date, timeZone?: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);
  const get = (type: string) => Number(parts.find((part) => part.type === type)?.value);
  return Date.UTC(get("year"), get("month") - 1, get("day")) / 86_400_000;
}

/**
 * A list's time: "Just now", "12m ago", "3h ago", "Yesterday", "Sep 24",
 * and the year once it isn't this one. `now` and `timeZone` are injectable
 * for tests; the browser's own zone otherwise.
 */
export function relativeTime(iso: string, now: Date = new Date(), timeZone?: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const seconds = (now.getTime() - date.getTime()) / 1000;
  if (seconds < 60) return "Just now";
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  const days = dayNumber(now, timeZone) - dayNumber(date, timeZone);
  if (days === 0) return `${Math.floor(seconds / 3600)}h ago`;
  if (days === 1) return "Yesterday";
  const sameYear =
    new Intl.DateTimeFormat("en-US", { timeZone, year: "numeric" }).format(date) ===
    new Intl.DateTimeFormat("en-US", { timeZone, year: "numeric" }).format(now);
  return date.toLocaleDateString("en-US", {
    timeZone,
    month: "short",
    day: "numeric",
    ...(sameYear ? {} : { year: "numeric" }),
  });
}

/** The reader's time: "Sep 27, 2026 at 3:44 PM". */
export function exactTime(iso: string, timeZone?: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const day = date.toLocaleDateString("en-US", {
    timeZone,
    month: "short",
    day: "numeric",
    year: "numeric",
  });
  const time = date.toLocaleTimeString("en-US", { timeZone, hour: "numeric", minute: "2-digit" });
  return `${day} at ${time}`;
}

/** "AP · 2h ago", or whichever half exists. */
export function storyMeta(story: NewsStory, time: string | undefined): string | undefined {
  const parts = [story.attribution, time].filter((part): part is string => !!part);
  return parts.length > 0 ? parts.join(" · ") : undefined;
}
