// The postseason as a bracket — the web twin of iOS `Postseason`
// (StatSideShared/Models/Postseason.swift) and the geometry its
// `PostseasonSection` lays out.
//
// Pure: rounds, advancement and placement are all derivable from the games,
// so the shape a bracket takes is testable without a component in sight.

import type { Game, Team } from "@/lib/types";
import { playsSeries, type League } from "@/lib/leagues";

/** ESPN's `season.type` for the postseason. */
export const POSTSEASON_SEASON_TYPE = 3;

export interface PostseasonRound {
  name: string;
  games: Game[];
  /**
   * The real game each series card opens, by card id — the series' live
   * game, its next one, or the one that decided it. Absent for a league of
   * single games, whose cards are games already.
   */
  opens?: Record<string, Game>;
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
 * The series leagues (the NBA, NHL, MLB and WNBA) name their rounds off
 * the headline too, and `postseasonRounds` draws each series as one card
 * (iOS, 2026-11-03), so `feeders` reads a series winner the way it reads a
 * game winner.
 */
function roundName(game: Game, league: League): string | undefined {
  switch (league) {
    case "nfl":
      return nflRoundName(game.week);
    case "cfb":
      return collegeRoundName(game.headline);
    case "nba":
    case "nhl":
    case "mlb":
    case "wnba":
      return seriesRoundName(game.headline, league);
    case "mcbb":
    case "wcbb":
      return basketballRoundName(game.headline);
  }
}

/**
 * The NCAA tournament's rounds (iOS `Postseason.basketballName`, 2026-11-02),
 * off headlines like "NCAA Men's Basketball Championship - South Region -
 * Sweet 16". Single elimination, so the bracket's results-only feeder rule
 * holds. The NIT, Women's NIT, WBIT and Crown share the postseason season
 * type and name nothing, like a bowl.
 */
export function basketballRoundName(headline: string | undefined): string | undefined {
  if (!headline) return undefined;
  const text = headline.toLowerCase();
  if (!text.startsWith("ncaa ") || !text.includes("basketball championship")) {
    return undefined;
  }
  if (text.includes("national championship")) return "National Championship";
  if (text.includes("final four")) return "Final Four";
  if (text.includes("elite 8") || text.includes("elite eight")) return "Elite Eight";
  if (text.includes("sweet 16") || text.includes("sweet sixteen")) return "Sweet 16";
  if (text.includes("first four")) return "First Four";
  if (text.includes("2nd round") || text.includes("second round")) return "Second Round";
  if (text.includes("1st round") || text.includes("first round")) return "First Round";
  return "NCAA Tournament";
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
  const rounds = [...grouped.entries()]
    .map(([name, roundGames]) => {
      const sorted = [...roundGames].sort((a, b) => kickoff(a) - kickoff(b));
      return playsSeries(league) ? seriesRound(name, sorted) : { name, games: sorted };
    })
    .sort((a, b) => roundKickoff(a) - roundKickoff(b));
  return playsSeries(league) ? settledRounds(rounds) : rounds;
}

/**
 * A series league's round, off headlines like "ALDS - Game 3", "West 1st
 * Round - Game 2", "WNBA Finals - Game 7" (iOS `Postseason.seriesName`,
 * probed 2026-11-03). A bracket's two halves are one round — the ALDS and
 * the NLDS are the Division Series — because the bracket pairs a round
 * against the next, and the final is fed from both. The NBA's play-in never
 * gets here: ESPN files it as its own season type (5).
 */
export function seriesRoundName(
  headline: string | undefined,
  league: League
): string | undefined {
  if (!headline) return undefined;
  const text = (headline.split(" - Game")[0] ?? headline).toLowerCase();
  switch (league) {
    case "mlb":
      if (text.includes("world series")) return "World Series";
      if (text.endsWith("cs") || text.includes("championship series")) return "Championship Series";
      if (text.endsWith("ds") || text.includes("division series")) return "Division Series";
      if (text.endsWith("wc") || text.includes("wild card")) return "Wild Card";
      break;
    case "nba":
      if (text.startsWith("nba finals")) return "NBA Finals";
      // Before "finals", which "semifinals" contains.
      if (text.includes("semifinals")) return "Conference Semifinals";
      if (text.includes("finals")) return "Conference Finals";
      if (text.includes("1st round") || text.includes("first round")) return "First Round";
      break;
    case "nhl":
      if (text.includes("stanley cup")) return "Stanley Cup Final";
      if (text.includes("final")) return "Conference Finals";
      if (text.includes("2nd round") || text.includes("second round")) return "Second Round";
      if (text.includes("1st round") || text.includes("first round")) return "First Round";
      break;
    case "wnba":
      if (text.includes("semifinals")) return "Semifinals";
      if (text.includes("finals")) return "Finals";
      if (text.includes("1st round") || text.includes("first round")) return "First Round";
      break;
    default:
      return undefined;
  }
  // A playoff game in a round we don't know yet still shows.
  return "Playoffs";
}

function isStarted(game: Game): boolean {
  return game.status !== "scheduled" && game.status !== "postponed" && game.status !== "cancelled";
}

function isLive(game: Game): boolean {
  return game.status === "in_progress" || game.status === "halftime" ||
    game.status === "end_period" || game.status === "delayed";
}

/**
 * One card per series: the round's games grouped by their two teams, each
 * group drawn as a single game whose scores are series wins and whose winner
 * is the series winner once decided — so `bracketPairing` and `feeders` wire
 * a series bracket with no rule of their own.
 */
export function seriesRound(name: string, games: Game[]): PostseasonRound {
  const grouped = new Map<string, Game[]>();
  for (const game of games) {
    const key = [game.homeTeam.team.id, game.awayTeam.team.id].sort().join("|");
    const bucket = grouped.get(key);
    if (bucket) bucket.push(game);
    else grouped.set(key, [game]);
  }
  const opens: Record<string, Game> = {};
  const cards: Game[] = [];
  for (const series of grouped.values()) {
    const card = seriesCard(series, name);
    if (!card) continue;
    const open = seriesOpening(series);
    if (open) opens[card.id] = open;
    cards.push(card);
  }
  cards.sort((a, b) => kickoff(a) - kickoff(b));
  return { name, games: cards, opens };
}

/**
 * One series as a card. Game 1's sides keep their places — the better seed
 * hosts it — and the record is the latest played game's, which ESPN stamps
 * as it stood after that game.
 */
export function seriesCard(games: Game[], round: string): Game | undefined {
  const sorted = [...games].sort((a, b) => kickoff(a) - kickoff(b));
  const first = sorted[0];
  if (!first) return undefined;
  const started = sorted.filter(isStarted);
  const record =
    [...started].reverse().find((game) => game.series)?.series ??
    [...sorted].reverse().find((game) => game.series)?.series;
  const wins = record?.wins ?? {};
  const decided = record?.completed === true;
  const leader = Object.entries(wins).sort((a, b) => b[1] - a[1])[0]?.[0];
  const live = sorted.find(isLive);

  const side = (team: Game["homeTeam"]): Game["homeTeam"] => ({
    team: team.team,
    score: started.length === 0 ? null : (wins[team.team.id] ?? 0),
    ranking: team.ranking,
    record: team.record,
    isWinner: decided ? team.team.id === leader : undefined,
  });

  return {
    ...first,
    id: `series-${first.id}`,
    week: undefined,
    headline: round,
    series: record ?? { completed: false, wins: {} },
    status: decided ? "complete" : (live?.status ?? "scheduled"),
    clock: decided ? undefined : live?.clock,
    quarter: decided ? undefined : live?.quarter,
    livePhase: decided ? undefined : live?.livePhase,
    statusDetail: decided ? record?.summary : (live?.statusDetail ?? record?.summary),
    homeTeam: side(first.homeTeam),
    awayTeam: side(first.awayTeam),
    broadcast: undefined,
    possession: undefined,
  };
}

/**
 * The game a series card opens: the one being played, else the next one
 * scheduled, else the last one played.
 */
export function seriesOpening(games: Game[]): Game | undefined {
  const sorted = [...games].sort((a, b) => kickoff(a) - kickoff(b));
  return (
    sorted.find(isLive) ??
    sorted.find((game) => game.status === "scheduled") ??
    sorted[sorted.length - 1]
  );
}

/**
 * A series whose deciding game the slate is missing, settled by who played
 * on: exactly one of its teams in a later round means that team won it, with
 * the wins it takes to clinch (iOS `Postseason.settled`, seen live on the
 * NHL's 2026 first round). Results-only, like `feeders`.
 */
export function settledRounds(rounds: PostseasonRound[]): PostseasonRound[] {
  return rounds.map((round, index) => {
    const later = new Set(
      rounds
        .slice(index + 1)
        .flatMap((next) => next.games)
        .flatMap((game) => [game.homeTeam.team.id, game.awayTeam.team.id])
    );
    const games = round.games.map((card) => {
      if (winnerTeamId(card) !== undefined || !card.series) return card;
      const through = [card.homeTeam.team.id, card.awayTeam.team.id].filter((id) =>
        later.has(id)
      );
      if (through.length !== 1) return card;
      return settleSeries(card, through[0]);
    });
    return { ...round, games };
  });
}

function settleSeries(card: Game, winner: string): Game {
  const series = card.series ?? { completed: false, wins: {} };
  const clinch = series.length !== undefined ? Math.floor(series.length / 2) + 1 : 0;
  const side = (team: Game["homeTeam"]): Game["homeTeam"] => {
    const won = team.team.id === winner;
    return {
      ...team,
      score: won ? Math.max(clinch, team.score ?? 0) : team.score,
      isWinner: won,
    };
  };
  const homeTeam = side(card.homeTeam);
  const awayTeam = side(card.awayTeam);
  const [top, bottom] = homeTeam.isWinner ? [homeTeam, awayTeam] : [awayTeam, homeTeam];
  const summary = `${top.team.abbreviation || top.team.school} wins series ${top.score ?? 0}-${bottom.score ?? 0}`;
  return {
    ...card,
    status: "complete",
    statusDetail: summary,
    series: {
      ...series,
      summary,
      completed: true,
      wins: {
        ...series.wins,
        [homeTeam.team.id]: homeTeam.score ?? 0,
        [awayTeam.team.id]: awayTeam.score ?? 0,
      },
    },
    homeTeam,
    awayTeam,
  };
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
