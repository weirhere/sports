// The postseason as a bracket — the web twin of iOS `Postseason`
// (StatSideShared/Models/Postseason.swift) and the geometry its
// `PostseasonSection` lays out.
//
// Pure: rounds, advancement and placement are all derivable from the games,
// so the shape a bracket takes is testable without a component in sight.

import type { Game, Team } from "@/lib/types";
import type { League } from "@/lib/leagues";

/** ESPN's `season.type` for the postseason. */
export const POSTSEASON_SEASON_TYPE = 3;

export interface PostseasonRound {
  name: string;
  games: Game[];
}

function kickoff(game: Game): number {
  const parsed = Date.parse(game.scheduledAt);
  return Number.isNaN(parsed) ? Number.POSITIVE_INFINITY : parsed;
}

/** When the round starts — what orders the chips. */
export function roundKickoff(round: PostseasonRound): number {
  return Math.min(...round.games.map(kickoff), Number.POSITIVE_INFINITY);
}

/** True once every game in the round has been played. */
export function roundIsComplete(round: PostseasonRound): boolean {
  return (
    round.games.length > 0 &&
    round.games.every((game) => game.status === "complete")
  );
}

export function postseasonGames(games: Game[]): Game[] {
  return games.filter((game) => game.seasonType === POSTSEASON_SEASON_TYPE);
}

/**
 * The round a game belongs to, or undefined where it belongs to no round —
 * a bowl, which is postseason football but not playoff football.
 *
 * The two leagues encode it completely differently, which is why this is a
 * mapping and not a field. **The NFL** numbers its rounds as `seasontype=3`
 * weeks. **College football** files its entire postseason under one week —
 * 46 games in week 1, bowls and playoff alike — so the round lives in
 * ESPN's printed headline and nowhere else.
 *
 * The NBA and NHL name nothing: their playoffs are best-of-seven *series*,
 * and this bracket models single elimination — `feeders` reads advancement
 * off "a completed game's winner turns up in a later game", which is true
 * of every game of a series against the same opponent. Naming no round
 * means `postseasonRounds` produces none and the tab never appears, which
 * is the deferral made explicit rather than accidental.
 */
function roundName(game: Game, league: League): string | undefined {
  switch (league) {
    case "nfl":
      return nflRoundName(game.week);
    case "cfb":
      return collegeRoundName(game.headline);
    case "nba":
    case "nhl":
      return undefined;
  }
}

function nflRoundName(week: number | undefined): string {
  switch (week) {
    case 1:
      return "Wild Card";
    case 2:
      return "Divisional";
    case 3:
      return "Conference Championships";
    case 5:
      return "Super Bowl";
    // Week 4 never reaches here — the exhibition is filtered out before
    // anything is named.
    default:
      return "Postseason";
  }
}

/**
 * Matched on ESPN's own wording, loosely: the headlines carry sponsor names
 * and venues ("College Football Playoff Quarterfinal at the Allstate Sugar
 * Bowl"), so the round is a substring, never the whole string.
 *
 * A quarterfinal played *at* a bowl is a quarterfinal, which is why the
 * playoff rounds are all checked and a bowl is only what's left over —
 * undefined, and out of the bracket. That is deliberate (iOS, 2026-09-06:
 * "reserve that tab just for the playoffs"): thirty-eight exhibitions in a
 * column marked "Bowls" was the biggest thing on a screen whose subject is
 * a twelve-team bracket, and nothing about a bowl is bracket-shaped. They
 * keep their place on the Games tab, in date order with the rest.
 */
function collegeRoundName(headline: string | undefined): string | undefined {
  if (!headline) return undefined;
  const text = headline.toLowerCase();
  if (text.includes("national championship")) return "National Championship";
  if (text.includes("semifinal")) return "Semifinals";
  if (text.includes("quarterfinal")) return "Quarterfinals";
  if (text.includes("first round")) return "First Round";
  return undefined;
}

/**
 * The postseason games that are not part of the bracket: the NFL's Pro
 * Bowl, filed under the same season type but fed by nothing and feeding
 * nothing.
 *
 * It shows beneath the last round rather than beside it (iOS, 2026-09-06) —
 * FotMob's treatment of a World Cup's bronze final, which has exactly the
 * same problem. A chip of its own put an all-star game between the
 * conference championships and the Super Bowl, which is the one thing a
 * bracket must never imply.
 */
export function postseasonExhibition(
  games: Game[],
  league: League
): PostseasonRound | undefined {
  if (league !== "nfl") return undefined;
  const matches = postseasonGames(games)
    .filter((game) => game.week === 4)
    .sort((a, b) => kickoff(a) - kickoff(b));
  return matches.length > 0 ? { name: "Pro Bowl", games: matches } : undefined;
}

/**
 * The postseason split into rounds a fan would name.
 *
 * Rounds order by first kickoff rather than by a hardcoded sequence, which
 * is the one rule that reads correctly for both leagues: the NFL's weeks are
 * already chronological, and it puts college football's rounds in order
 * without either league needing a special case.
 */
export function postseasonRounds(
  games: Game[],
  league: League
): PostseasonRound[] {
  const exhibitionIds = new Set(
    postseasonExhibition(games, league)?.games.map((game) => game.id) ?? []
  );
  const bracketGames = postseasonGames(games).filter(
    (game) => !exhibitionIds.has(game.id) && roundName(game, league) !== undefined
  );
  if (bracketGames.length === 0) return [];

  const grouped = new Map<string, Game[]>();
  for (const game of bracketGames) {
    const name = roundName(game, league) ?? "";
    const bucket = grouped.get(name);
    if (bucket) bucket.push(game);
    else grouped.set(name, [game]);
  }
  return [...grouped.entries()]
    .map(([name, roundGames]) => ({
      name,
      games: [...roundGames].sort((a, b) => kickoff(a) - kickoff(b)),
    }))
    .sort((a, b) => roundKickoff(a) - roundKickoff(b));
}

/**
 * The round a page should open on: the first one still being played, or the
 * last one when the postseason is over — never the Wild Card round in
 * February.
 */
export function defaultRound(rounds: PostseasonRound[]): string | undefined {
  return (
    rounds.find((round) => !roundIsComplete(round))?.name ??
    rounds[rounds.length - 1]?.name
  );
}

/** The winning side's team id, once there is one. */
export function winnerTeamId(game: Game): string | undefined {
  if (game.homeTeam.isWinner === true) return game.homeTeam.team.id;
  if (game.awayTeam.isWinner === true) return game.awayTeam.team.id;
  return undefined;
}

/**
 * The games in `previous` whose winner turns up in `game` — the only
 * advancement we can prove.
 *
 * Read off results, never off seeds. ESPN publishes no bracket tree, so the
 * alternative would be assuming that the first two games of a round feed the
 * first game of the next — wrong the moment a format reseeds, and wrong
 * invisibly. A round nobody has played yet therefore draws no lines at all,
 * and the bracket wires itself up as results land. A wrong line is far worse
 * than a missing one.
 */
export function feeders(game: Game, previous: Game[]): Game[] {
  const sides = new Set([game.homeTeam.team.id, game.awayTeam.team.id]);
  return previous.filter((earlier) => {
    const winner = winnerTeamId(earlier);
    return winner !== undefined && sides.has(winner);
  });
}

/** What feeds one game of the next round: an earlier game, or a team that
 *  sat the round out. */
export type BracketSource =
  | { kind: "game"; id: string; game: Game }
  | { kind: "bye"; id: string; team: Team };

export interface BracketPairing {
  /** The left column, top to bottom — already ordered so each next-round
   *  game's own sources sit together. */
  sources: BracketSource[];
  /** Each next-round game with the positions in `sources` that feed it. */
  links: { game: Game; sourceIndices: number[] }[];
}

/**
 * Pair a round against the next one, so the bracket can be *drawn* rather
 * than merely listed (iOS, 2026-09-06: chronological columns "doesn't make
 * sense with how the advancements occur").
 *
 * Two things were wrong with listing both rounds by kickoff: the next
 * round's games sat wherever the calendar put them, so a winner's line
 * crossed the column to reach its game; and a team that earned a bye
 * appeared in the second column having never been in the first.
 *
 * So the left column is rebuilt in *bracket* order — for each game of the
 * next round, the sources that produce it, byes first (a bye is always the
 * better seed) — and each next-round game is placed level with its own
 * sources. Lines then run straight across.
 *
 * Returns undefined when the two rounds aren't connected by any result we
 * can see: a round nobody has played yet proves nothing. The caller falls
 * back to two plain columns, which is honest about knowing no more.
 */
export function bracketPairing(
  round: Game[],
  next: Game[]
): BracketPairing | undefined {
  const played = new Set(
    round.flatMap((game) => [game.homeTeam.team.id, game.awayTeam.team.id])
  );
  const sources: BracketSource[] = [];
  const index = new Map<string, number>();
  const links: { game: Game; sourceIndices: number[] }[] = [];
  let connected = false;

  for (const game of [...next].sort((a, b) => kickoff(a) - kickoff(b))) {
    const fed = feeders(game, round);
    if (fed.length > 0) connected = true;
    // A side that never appeared in this round didn't lose its way here —
    // it sat the round out. Only meaningful once something in this pairing
    // is connected at all, which the undefined return below enforces.
    const byes: BracketSource[] = [game.awayTeam, game.homeTeam]
      .filter((side) => !played.has(side.team.id))
      .map((side) => ({
        kind: "bye" as const,
        id: `bye-${side.team.league}-${side.team.id}`,
        team: side.team,
      }));
    const indices: number[] = [];
    for (const source of [
      ...byes,
      ...fed.map(
        (game): BracketSource => ({ kind: "game", id: `game-${game.id}`, game })
      ),
    ]) {
      const existing = index.get(source.id);
      if (existing !== undefined) {
        indices.push(existing);
      } else {
        index.set(source.id, sources.length);
        indices.push(sources.length);
        sources.push(source);
      }
    }
    links.push({ game, sourceIndices: indices });
  }
  if (!connected) return undefined;

  // A game of this round that fed nothing visible still belongs on screen —
  // a round is never partly shown.
  for (const game of round) {
    if (!index.has(`game-${game.id}`)) {
      sources.push({ kind: "game", id: `game-${game.id}`, game });
    }
  }
  return { sources, links };
}

// MARK: - Geometry
//
// The bracket is absolutely positioned, because the pairing is derived from
// results rather than from position: which slot a card lands in can't be
// expressed as document order.

export const BRACKET_CARD_HEIGHT = 82;
export const BRACKET_BYE_HEIGHT = 46;
export const BRACKET_CARD_GAP = 8;

export function sourceHeight(source: BracketSource | undefined): number {
  return source?.kind === "bye" ? BRACKET_BYE_HEIGHT : BRACKET_CARD_HEIGHT;
}

/** Where each left-column slot starts. Cumulative rather than arithmetic,
 *  because a bye entry is shorter than a game. */
export function sourceTops(sources: BracketSource[]): number[] {
  const tops: number[] = [];
  let y = 0;
  for (const source of sources) {
    tops.push(y);
    y += sourceHeight(source) + BRACKET_CARD_GAP;
  }
  return tops;
}

/**
 * Each next-round game centred on its own sources, then nudged down wherever
 * two would overlap — a placement that collides is worse than one a few
 * pixels off its ideal centre.
 */
export function bracketPlacements(
  pairing: BracketPairing,
  tops: number[]
): { game: Game; top: number }[] {
  const ideal = pairing.links.map(({ game, sourceIndices }) => {
    const centres = sourceIndices
      .filter((i) => i >= 0 && i < tops.length)
      .map((i) => tops[i] + sourceHeight(pairing.sources[i]) / 2);
    if (centres.length === 0) return { game, top: 0 };
    const centre = centres.reduce((sum, c) => sum + c, 0) / centres.length;
    return { game, top: centre - BRACKET_CARD_HEIGHT / 2 };
  });
  ideal.sort((a, b) => a.top - b.top);

  const placed: { game: Game; top: number }[] = [];
  for (const entry of ideal) {
    const last = placed[placed.length - 1];
    const floor = last ? last.top + BRACKET_CARD_HEIGHT + BRACKET_CARD_GAP : 0;
    placed.push({ game: entry.game, top: Math.max(entry.top, floor) });
  }
  return placed;
}

/** How tall the drawn bracket is — whichever column runs longer. */
export function bracketHeight(
  pairing: BracketPairing,
  tops: number[],
  placements: { top: number }[]
): number {
  const left =
    tops.length > 0
      ? tops[tops.length - 1] + sourceHeight(pairing.sources[tops.length - 1])
      : 0;
  const right = placements.reduce(
    (max, p) => Math.max(max, p.top + BRACKET_CARD_HEIGHT),
    0
  );
  return Math.max(left, right);
}
