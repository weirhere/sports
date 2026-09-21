// What a team has won, and where each answer came from — the web twin of iOS
// `TeamTrophies` (StatSideShared/Models/TeamTrophies.swift).
//
// ESPN publishes **no team trophy list anywhere**. What it does publish is the
// trophy *game*, by name: every competition carries `notes[].headline`, and
// Georgia's week-15 event reads exactly "SEC Championship". So a title is one
// completed game with its name printed on it, and the team's own result says
// who holds it.
//
// That gives a trophy case two sources, covering different eras:
//
// - **Derived**, from ESPN, for every season back to `SEASON_FLOOR`. Nothing
//   here is hand-maintained, so nothing here can go stale or be silently
//   dropped the year someone forgets to append a row.
// - **`trophy-registry.ts`**, hardcoded, for the closed history before that
//   floor — the seasons ESPN's season axis cannot reach at all.
//
// They merge by (kind, year), so a title both sources know about is one row,
// not two. Each group then reports the span it can actually speak for, because
// a case that quietly starts in 2014 is the lie-by-omission this app keeps
// refusing — Alabama has eighteen national titles and a derived-only case
// would show six of them with no hint that the number was partial.

import type { Game } from "@/lib/types";
import type { League } from "@/lib/leagues";

/**
 * Which shelf a trophy sits on. Ordering only — a league title leads, because
 * it is the one a fan came to the tab to count.
 */
export type TrophyTier = "league" | "conference";

const TIER_ORDER: Record<TrophyTier, number> = { league: 0, conference: 1 };

/**
 * A trophy's identity, kept as both forms rather than pluralized by string
 * surgery — "NBA Finals" is already plural and "Stanley Cups" is not what
 * appending an s to "Stanley Cup Final" would give you.
 */
export interface TrophyKind {
  /** What one of them is called: "Super Bowl", "SEC Championship". */
  singular: string;
  /** What a shelf of them is called: "Super Bowls", "SEC Championships". */
  plural: string;
  tier: TrophyTier;
}

export interface Trophy {
  kind: TrophyKind;
  /**
   * The season it was won in, on the app's own axis — the year a season
   * *opens*, which is what `espnSeason` translates at the query string.
   */
  year: number;
}

/** What the years behind a row can be trusted to cover. */
export type TrophyCoverage =
  | { kind: "allTime" }
  | { kind: "since"; year: number };

/** One row of the trophy case: a trophy, and the years this team won it. */
export interface TrophyGroup {
  id: string;
  kind: TrophyKind;
  /** Newest first — a fan reads the most recent one as the headline. */
  years: number[];
  coverage: TrophyCoverage;
}

/** A team's shelf, assembled and ready to render. */
export interface TrophyCase {
  /**
   * League titles first, then conference titles; within a tier, the most-won
   * trophy leads, and an equal count breaks on the most recent win so a live
   * case reorders as titles land rather than alphabetically.
   */
  groups: TrophyGroup[];
}

export function trophyName(kind: TrophyKind, count: number): string {
  return count === 1 ? kind.singular : kind.plural;
}

/**
 * What makes two trophies the same trophy, and it **folds case**.
 *
 * ESPN does not spell a headline the same way twice: the Rams' 2021 season
 * calls it "NFC Championship" and their 2018 season calls it "NFC
 * CHAMPIONSHIP", which grouped as two kinds and so printed two rows reading
 * "1" where the shelf holds two of one thing (Andy, 2026-09-21). Since the
 * name is taken from the wire by design — see `trophyKindFromHeadline` — the
 * wire's typography cannot be allowed to be identity.
 */
export function trophyKindIdentity(kind: TrophyKind): string {
  return kind.singular.toLowerCase();
}

/** Identity as a map key. The tier is part of it, as it is on iOS. */
function trophyKindKey(kind: TrophyKind): string {
  return `${kind.tier}\u0000${trophyKindIdentity(kind)}`;
}

/**
 * All caps, and not merely for want of a lowercase form — "NFC CHAMPIONSHIP"
 * is shouting, "Big 12" and "2018" are not.
 */
function isShouting(text: string): boolean {
  return text !== text.toLowerCase() && text === text.toUpperCase();
}

/** How loud a spelling is, for choosing between two of them. */
function shoutiness(text: string): number {
  let loud = 0;
  for (const character of text) {
    if (character !== character.toLowerCase()) loud += 1;
  }
  return loud;
}

/**
 * Which of two spellings of one trophy a row prints.
 *
 * Never a third spelling: both candidates are ESPN's own words, and the
 * calmer one wins — counted, rather than an all-caps test, because the pair
 * that needs deciding is often only half-shouted ("BIG TEN Championship"
 * against "Big Ten Championship", once the common noun above has been
 * fixed). A genuine tie breaks lexicographically, so a shelf can't reorder
 * its own letters between loads.
 */
function preferredSpelling(lhs: TrophyKind, rhs: TrophyKind): TrophyKind {
  const left = shoutiness(lhs.singular);
  const right = shoutiness(rhs.singular);
  if (left !== right) return left < right ? lhs : rhs;
  return lhs.singular <= rhs.singular ? lhs : rhs;
}

export function trophyGroupTitle(group: TrophyGroup): string {
  return trophyName(group.kind, group.years.length);
}

export function trophyCaseIsEmpty(shelf: TrophyCase): boolean {
  return shelf.groups.length === 0;
}

/**
 * The narrowest span any row is limited to, or undefined when every row is
 * all-time. What the card's one footnote says, so the caption is stated once
 * for the shelf instead of repeated on every row.
 */
export function coverageFloor(shelf: TrophyCase): number | undefined {
  const floors = shelf.groups
    .map((group) => (group.coverage.kind === "since" ? group.coverage.year : undefined))
    .filter((year): year is number => year !== undefined);
  return floors.length > 0 ? Math.min(...floors) : undefined;
}

// --- Reading a trophy off a headline --------------------------------------

/**
 * Whether a round name is the one that hands over a trophy.
 *
 * "Quarterfinals" and "Semifinals" both end in "final", which is the whole
 * problem: a substring test for it promotes a team knocked out in the first
 * round to champion — and the NHL called its early rounds "Stanley Cup
 * Quarterfinals" for decades. So a qualified round is ruled out by name, and
 * what's left has to be the last word.
 */
function decidesATrophy(text: string): boolean {
  if (text.includes("quarterfinal") || text.includes("semifinal")) return false;
  if (text.includes("championship")) return true;
  return text.endsWith("final") || text.endsWith("finals");
}

/**
 * "SEC Championship", "AFC Championship" — the headline is already the
 * trophy's name, so it is kept as written (bar a trailing "Game") rather than
 * re-spelled from a conference registry. A conference we have never heard of
 * still reads correctly, one that renames itself needs no code change, and a
 * sponsor in the string is ESPN's own wording rather than ours to strip.
 *
 * Guarded on the word ending the headline, so "Championship Week" and a
 * passing mention are both out. A trailing "Game" is tolerated because it is a
 * coin-flip which way ESPN spells any given one — the captured SEC title game
 * is plain "SEC Championship", and a league that writes "AFC Championship
 * Game" must not silently win nothing.
 */
function conferenceChampionship(
  headline: string,
  text: string
): TrophyKind | undefined {
  let tail = text;
  let name = headline.trim();
  // The trophy is named after itself, not after the fixture: a team holds
  // three AFC Championships, it does not hold three AFC Championship Games.
  if (tail.endsWith(" game")) {
    tail = tail.slice(0, -5);
    name = name.slice(0, -5).trim();
  }
  if (!tail.endsWith("championship") || tail === "championship") return undefined;
  // One word is re-cased, and only one: ESPN shouts "NFC CHAMPIONSHIP" in
  // some seasons and writes "NFC Championship" in others, and a row must not
  // print a shout because of which season it was derived from. The
  // conference's own letters stay ESPN's, because re-casing those would have
  // to guess whether a token is an acronym ("SEC") or a word ("Big Ten") —
  // and on an all-caps string it would guess wrong either way round.
  // `trophyKindIdentity` covers the prefix instead.
  const named = `${name.slice(0, -"championship".length)}Championship`;
  return { singular: named, plural: `${named}s`, tier: "conference" };
}

/**
 * The NBA's and NHL's conference round: "Eastern Conference Finals". Already
 * plural, like the NBA Finals it sits under.
 */
function conferenceFinals(
  headline: string,
  text: string
): TrophyKind | undefined {
  if (!text.includes("conference final")) return undefined;
  const trimmed = headline.trim();
  // The same shout as above, and here it can be fixed outright rather than a
  // word at a time: this path only matches "<side> Conference Final(s)",
  // which is ordinary words with no acronym for a capitalization pass to
  // mangle.
  const name = isShouting(trimmed)
    ? trimmed.replace(/\S+/g, (word) => word[0] + word.slice(1).toLowerCase())
    : trimmed;
  return { singular: name, plural: name, tier: "conference" };
}

/**
 * The trophy a game's printed headline names, or undefined.
 *
 * Matched on ESPN's own wording and **silent on everything else**, which is
 * the gate the whole feature rests on: branded kickoffs and neutral-site
 * regular games live in this same field. "Aflac Kickoff", "Aer Lingus College
 * Football Classic", "NFL Melbourne Game" and "NBA Cup - Group Play" are all
 * real headlines on games that win nothing, so an unrecognized one contributes
 * no row rather than a generic "Trophy" — `roundName`'s pattern in
 * `postseason.ts` exactly, which already reads a playoff round out of a
 * sponsor-laden string and returns undefined for a bowl.
 *
 * The league title is always checked first: "College Football Playoff National
 * Championship" contains "championship", so a conference rule that ran first
 * would claim it.
 */
export function trophyKindFromHeadline(
  headline: string | undefined,
  league: League
): TrophyKind | undefined {
  if (!headline) return undefined;
  const text = headline.toLowerCase();
  if (text.length === 0) return undefined;

  switch (league) {
    case "cfb":
      if (text.includes("national championship")) {
        return {
          singular: "National Championship",
          plural: "National Championships",
          tier: "league",
        };
      }
      return conferenceChampionship(headline, text);
    case "nfl":
      if (text.includes("super bowl")) {
        return { singular: "Super Bowl", plural: "Super Bowls", tier: "league" };
      }
      return conferenceChampionship(headline, text);
    case "nba":
      // Named exactly, and checked before the conference round below — both
      // spell "Finals", and only one of them is the title.
      if (text.includes("nba finals")) {
        return { singular: "NBA Finals", plural: "NBA Finals", tier: "league" };
      }
      // The in-season tournament is a real trophy; its group stage and its
      // earlier rounds are not. "NBA Cup - Group Play" and "NBA Cup -
      // Quarterfinals" are both confirmed headlines on regular-season games.
      if (text.includes("nba cup") && decidesATrophy(text)) {
        return { singular: "NBA Cup", plural: "NBA Cups", tier: "league" };
      }
      return conferenceFinals(headline, text);
    case "nhl":
      if (text.includes("stanley cup") && decidesATrophy(text)) {
        return { singular: "Stanley Cup", plural: "Stanley Cups", tier: "league" };
      }
      return conferenceFinals(headline, text);
  }
}

// --- Deriving a season's titles -------------------------------------------

function kickoff(game: Game): number {
  const parsed = Date.parse(game.scheduledAt);
  return Number.isNaN(parsed) ? -Infinity : parsed;
}

/**
 * Every trophy one season's games show a team won.
 *
 * Two rules, both load-bearing:
 *
 * **A scheduled title game wins nothing.** Only a completed game counts, so a
 * conference championship a team is about to play contributes no row. The tab
 * is what a team *has*; the Games tab is where a final they are yet to play
 * belongs.
 *
 * **A series needs no series decoding.** The NBA's and NHL's finals are four
 * to seven games all carrying one headline, and the champion is the winner of
 * the chronologically **last completed** one — which is also the right answer
 * for a single-game final, so one rule covers all four leagues. That is why
 * this groups by kind before it looks at any result: taking every won game
 * would credit a team that led a series 3-0 and lost it.
 */
export function deriveTrophies(
  games: Game[],
  context: { teamId: string; year: number; league: League }
): Trophy[] {
  const byKind = new Map<string, { kind: TrophyKind; games: Game[] }>();
  for (const game of games) {
    const kind = trophyKindFromHeadline(game.headline, context.league);
    if (!kind) continue;
    if (
      game.homeTeam.team.id !== context.teamId &&
      game.awayTeam.team.id !== context.teamId
    ) {
      continue;
    }
    const bucket = byKind.get(trophyKindKey(kind)) ?? { kind, games: [] };
    bucket.games.push(game);
    byKind.set(trophyKindKey(kind), bucket);
  }

  const won: Trophy[] = [];
  for (const { kind, games: candidates } of byKind.values()) {
    const decided = candidates
      .filter((game) => game.status === "complete")
      .sort((a, b) => kickoff(a) - kickoff(b));
    const clincher = decided[decided.length - 1];
    if (!clincher) continue;
    const mine = [clincher.homeTeam, clincher.awayTeam].find(
      (side) => side.team.id === context.teamId
    );
    if (mine?.isWinner !== true) continue;
    won.push({ kind, year: context.year });
  }
  return won;
}

/**
 * The shelf, from every season the page has derived plus the registry's closed
 * history.
 *
 * `derivedFloor` is the earliest season the derivation actually covers — the
 * app's season floor once every season has loaded, and nothing is rendered
 * before that point, since a half-loaded case would show a count that changes
 * under the reader.
 */
export function assembleTrophyCase(input: {
  derived: Trophy[];
  registry: Trophy[];
  /**
   * `trophyKindIdentity`s whose *whole* history the registry speaks for —
   * case-folded, so a list spelled one way and a derived row spelled another
   * still meet.
   */
  allTimeKinds: Set<string>;
  derivedFloor: number;
}): TrophyCase {
  // Merged on identity, so a title both sources know about is one row rather
  // than two. The registry's window and the derivation's are meant to abut
  // rather than overlap, but a registry populated past the floor is the normal
  // end state of this feature, not an error — so the overlap dedupes silently.
  // Keyed on identity, which folds case, so the surviving spelling is
  // chosen rather than left to whichever season arrived first.
  const wins = new Map<string, { kind: TrophyKind; years: Set<number> }>();
  for (const trophy of [...input.registry, ...input.derived]) {
    const key = trophyKindKey(trophy.kind);
    const bucket = wins.get(key);
    if (!bucket) {
      wins.set(key, { kind: trophy.kind, years: new Set([trophy.year]) });
      continue;
    }
    bucket.kind = preferredSpelling(bucket.kind, trophy.kind);
    bucket.years.add(trophy.year);
  }

  const groups: TrophyGroup[] = [...wins.values()].map(({ kind, years }) => ({
    id: kind.singular,
    kind,
    years: [...years].sort((a, b) => b - a),
    // All-time only where the registry says it speaks for this trophy's whole
    // history. Inferring it from the rows instead would read "the oldest one
    // we happen to know about" as "the oldest one there is" — so a team whose
    // only league title came in the derived era would claim a complete shelf,
    // which is the omission this caption exists to prevent.
    // Matched on identity, like everything else here — a registry row and a
    // derived one must not miss each other over a capital.
    coverage: input.allTimeKinds.has(trophyKindIdentity(kind))
      ? { kind: "allTime" as const }
      : { kind: "since" as const, year: input.derivedFloor },
  }));

  groups.sort((lhs, rhs) => {
    if (lhs.kind.tier !== rhs.kind.tier) {
      return TIER_ORDER[lhs.kind.tier] - TIER_ORDER[rhs.kind.tier];
    }
    if (lhs.years.length !== rhs.years.length) {
      return rhs.years.length - lhs.years.length;
    }
    const left = lhs.years[0] ?? 0;
    const right = rhs.years[0] ?? 0;
    if (left !== right) return right - left;
    return lhs.kind.singular.localeCompare(rhs.kind.singular);
  });

  return { groups };
}
