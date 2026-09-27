// ESPN's Gamecast, as a card, in every league (iOS `GamecastContent`,
// `ShotMap` and `SurfaceColors`, 2026-09-27): three labeled columns across
// the top, the surface beneath them — football's field, basketball's court,
// hockey's rink — and the last play under that.
//
// The card doesn't know which league it's showing: it prints a
// `GamecastContent`, and each league builds one here. That's what keeps the
// three from drifting apart, on either platform.

import type { Game, GameSituation, PlayItem, Team } from "@/lib/types";

/** One of the three header columns: "DOWN / 2nd & 4", "SHOTS / 10–7". A
 *  missing value prints "—" rather than dropping the column, so the other
 *  two never move. */
export interface GamecastSlot {
  label: string;
  value?: string;
}

export interface GamecastContent {
  /** Always three. */
  slots: [GamecastSlot, GamecastSlot, GamecastSlot];
  /** "Touchdown", "Goal" — shown in the slots' place while it stands. */
  result?: string;
  resultTeam?: Team;
  /** "Last play · 2nd & 15 at WSU 48", "Last play · Power play". */
  lastPlayLabel: string;
  lastPlayClock?: string;
  lastPlayText?: string;
  /** The card is one screen-reader element and this is what it says. */
  accessibilitySummary: string;
}

type Side = "away" | "home";

function teamWithId(game: Game, id: string | undefined): Team | undefined {
  if (id === undefined) return undefined;
  return [game.awayTeam.team, game.homeTeam.team].find(
    (team) => String(team.espnId) === id
  );
}

// MARK: - Football — Down · Ball on · Drive

export function footballGamecast(
  game: Game,
  situation: GameSituation
): GamecastContent {
  const offense = teamWithId(game, situation.possessionTeamId);
  const parts: string[] = [];
  if (situation.result) {
    const scorer = teamWithId(game, situation.resultTeamId)?.school;
    parts.push(
      [scorer, situation.result.toLowerCase()].filter(Boolean).join(" ")
    );
  } else {
    if (offense) parts.push(`${offense.school} ball`);
    if (situation.downDistanceText) parts.push(situation.downDistanceText);
    if (situation.possessionText) parts.push(situation.possessionText);
    if (situation.driveLine) parts.push(situation.driveLine);
  }
  if (situation.lastPlayText) parts.push(situation.lastPlayText);
  return {
    slots: [
      { label: "Down", value: situation.downDistanceText },
      { label: "Ball on", value: situation.possessionText },
      { label: "Drive", value: situation.driveLine },
    ],
    result: situation.result,
    resultTeam: teamWithId(game, situation.resultTeamId),
    lastPlayLabel: ["Last play", situation.lastPlayDownText]
      .filter(Boolean)
      .join(" · "),
    lastPlayClock: situation.lastPlayClock,
    lastPlayText: situation.lastPlayText,
    accessibilitySummary: parts.join(", "),
  };
}

// MARK: - Basketball and hockey

/** The card for a league drawn as a shot map, or undefined for one that
 *  isn't, or a feed with nothing played yet. */
export function shotMapGamecast(
  game: Game,
  plays: PlayItem[],
  allowsShootout: boolean
): GamecastContent | undefined {
  const last = plays[plays.length - 1];
  if (!last) return undefined;
  switch (game.league) {
    case "nba":
      return basketball(game, plays, last);
    case "nhl":
      return hockey(game, plays, last, allowsShootout);
    default:
      return undefined;
  }
}

// Basketball — Run · Lead · Lead changes

function basketball(
  game: Game,
  plays: PlayItem[],
  last: PlayItem
): GamecastContent {
  const abbr = (side: Side) =>
    (side === "away" ? game.awayTeam : game.homeTeam).team.abbreviation ||
    (side === "away" ? "Away" : "Home");
  const name = (side: Side) =>
    (side === "away" ? game.awayTeam : game.homeTeam).team.school || abbr(side);
  const currentRun = run(plays);
  const lead = margin(plays);
  const changes = leadChanges(plays);

  const leadText =
    lead === undefined
      ? undefined
      : lead === 0
        ? "Tied"
        : `${abbr(lead > 0 ? "away" : "home")} +${Math.abs(lead)}`;
  const spoken: string[] = [];
  if (currentRun) {
    spoken.push(`${name(currentRun.side)} on a ${currentRun.points}–0 run`);
  }
  if (lead !== undefined) {
    spoken.push(
      lead === 0
        ? "tied"
        : `${name(lead > 0 ? "away" : "home")} up ${Math.abs(lead)}`
    );
  }
  spoken.push(`${changes} lead ${changes === 1 ? "change" : "changes"}`);
  if (last.text) spoken.push(last.text);

  return {
    slots: [
      {
        label: "Run",
        value: currentRun
          ? `${abbr(currentRun.side)} ${currentRun.points}–0`
          : undefined,
      },
      { label: "Lead", value: leadText },
      { label: "Lead changes", value: String(changes) },
    ],
    lastPlayLabel: "Last play",
    lastPlayClock: last.clock,
    lastPlayText: last.text,
    accessibilitySummary: spoken.join(", "),
  };
}

/** The points one side has scored since the other last did. Undefined
 *  before anyone scores. */
export function run(
  plays: PlayItem[]
): { side: Side; points: number } | undefined {
  let away = 0;
  let home = 0;
  const scores: [Side, number][] = [];
  for (const play of plays) {
    if (play.awayScore === undefined || play.homeScore === undefined) continue;
    if (play.awayScore > away) scores.push(["away", play.awayScore - away]);
    if (play.homeScore > home) scores.push(["home", play.homeScore - home]);
    away = play.awayScore;
    home = play.homeScore;
  }
  const side = scores[scores.length - 1]?.[0];
  if (!side) return undefined;
  let points = 0;
  for (let i = scores.length - 1; i >= 0 && scores[i][0] === side; i--) {
    points += scores[i][1];
  }
  return { side, points };
}

/** Away minus home at the last play that carried a score. */
export function margin(plays: PlayItem[]): number | undefined {
  for (let i = plays.length - 1; i >= 0; i--) {
    const { awayScore, homeScore } = plays[i];
    if (awayScore !== undefined && homeScore !== undefined) {
      return awayScore - homeScore;
    }
  }
  return undefined;
}

/** How many times the lead has passed from one side to the other. A tie in
 *  between doesn't count on its own; the next lead decides. */
export function leadChanges(plays: PlayItem[]): number {
  let leader = 0;
  let changes = 0;
  for (const { awayScore: a, homeScore: h } of plays) {
    if (a === undefined || h === undefined || a === h) continue;
    const now = a > h ? 1 : -1;
    if (leader !== 0 && now !== leader) changes += 1;
    leader = now;
  }
  return changes;
}

// Hockey — Strength · Shots · Last goal

function hockey(
  game: Game,
  allPlays: PlayItem[],
  last: PlayItem,
  allowsShootout: boolean
): GamecastContent {
  const awayTeam = game.awayTeam.team;
  const homeTeam = game.homeTeam.team;
  const awayId = String(awayTeam.espnId);
  const plays = allPlays.filter((p) => !(allowsShootout && p.period === 5));
  const team = (id?: string) =>
    id === undefined ? undefined : id === awayId ? awayTeam : homeTeam;
  const other = (id?: string) =>
    id === undefined ? undefined : id === awayId ? homeTeam : awayTeam;
  const remaining = (play: PlayItem) =>
    remainingClock(play.clock, play.period, allowsShootout);
  const type = (play: PlayItem) => play.typeText?.toLowerCase() ?? "";

  // Strength, from the last play's team's side: their power play, or the
  // other side's when they're the ones short.
  const strength = ((): {
    value?: string;
    spoken?: string;
    label?: string;
  } => {
    switch (last.strength) {
      case "even-strength":
        return { value: "Even", spoken: "Even strength" };
      case "power-play":
      case "short-handed": {
        const t =
          last.strength === "power-play" ? team(last.teamId) : other(last.teamId);
        return {
          value: t?.abbreviation ? `${t.abbreviation} PP` : "PP",
          spoken: `${t?.school ?? ""} power play`.trim(),
          label: "Power play",
        };
      }
      case "empty-net":
        return { value: "Empty net", spoken: "Empty net", label: "Empty net" };
      default:
        return {};
    }
  })();

  const shots = { away: 0, home: 0 };
  for (const play of plays) {
    if (type(play) !== "shot" && type(play) !== "goal") continue;
    if (play.teamId === awayId) shots.away += 1;
    else if (play.teamId !== undefined) shots.home += 1;
  }

  let goalIndex = -1;
  let faceoffIndex = -1;
  plays.forEach((play, i) => {
    if (type(play) === "goal") goalIndex = i;
    if (type(play) === "face off") faceoffIndex = i;
  });
  const goal = goalIndex >= 0 ? plays[goalIndex] : undefined;
  const lastGoalText = goal
    ? [
        team(goal.teamId)?.abbreviation ?? "",
        goal.period === last.period
          ? remaining(goal)
          : goal.period !== undefined
            ? hockeyPeriodLabel(goal.period)
            : undefined,
      ]
        .filter((part): part is string => !!part)
        .join(" ")
    : undefined;
  // A goal holds the header until play restarts with a faceoff, the way a
  // touchdown holds it until the next snap.
  const goalStands =
    goal !== undefined && goalIndex > faceoffIndex && goal.period === last.period;

  const spoken: string[] = [];
  if (goalStands) spoken.push(`${team(goal.teamId)?.school ?? ""} goal`.trim());
  else if (strength.spoken) spoken.push(strength.spoken);
  spoken.push(
    `shots ${awayTeam.school || "away"} ${shots.away}, ${homeTeam.school || "home"} ${shots.home}`
  );
  if (last.text) spoken.push(last.text);

  return {
    slots: [
      { label: "Strength", value: strength.value },
      { label: "Shots", value: `${shots.away}–${shots.home}` },
      { label: "Last goal", value: lastGoalText || undefined },
    ],
    result: goalStands ? "Goal" : undefined,
    resultTeam: goalStands ? team(goal.teamId) : undefined,
    lastPlayLabel: ["Last play", strength.label].filter(Boolean).join(" · "),
    lastPlayClock: remaining(last),
    lastPlayText: last.text,
    accessibilitySummary: spoken.join(", "),
  };
}

/** "1st", "2nd", "3rd", "OT", "2OT" — iOS `GameStatus.periodLabel`. */
function hockeyPeriodLabel(period: number): string {
  if (period <= 3) return ["1st", "2nd", "3rd"][period - 1];
  if (period === 4) return "OT";
  return `${period - 3}OT`;
}

/**
 * Time left in the period from ESPN's hockey play clock, which counts *up*
 * ("0:29" is 29 seconds in). The header counts down, and the card must agree
 * with it. Twenty minutes a period; a regular season's overtime is five.
 */
export function remainingClock(
  elapsed: string | undefined,
  period: number | undefined,
  allowsShootout: boolean
): string | undefined {
  if (elapsed === undefined) return undefined;
  const parts = elapsed.split(":").map((part) => parseInt(part, 10));
  if (parts.length !== 2 || parts.some(Number.isNaN)) return elapsed;
  const length = (period ?? 1) > 3 && allowsShootout ? 5 * 60 : 20 * 60;
  const left = Math.max(0, length - (parts[0] * 60 + parts[1]));
  return `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
}

// MARK: - Shot map

/**
 * This period's shots where they were taken, on a surface drawn landscape
 * and whole, away team shooting right. Every mark is already in surface
 * units, so the views only scale:
 * - **Court**, 94 × 50 feet: x along the length from the left baseline, y
 *   across. ESPN folds every shot onto one half (x across, y out from the
 *   baseline), so each is unfolded to the basket its team attacks — home at
 *   the left, away at the right, a half-turn apart.
 * - **Rink**, 200 × 85 feet: x from the left boards, y from the top. Teams
 *   change ends every period, so a period whose away shots lean left is
 *   turned a half-turn to keep the away team shooting right.
 */
export interface ShotMap {
  surface: "court" | "rink";
  period: number;
  /** Oldest first; the last is the one the pin sits on. */
  marks: ShotMark[];
}

/** Shape carries the outcome and color the team, so no mark relies on color
 *  alone. `made` is a basket, or a hockey shot on goal that was saved. */
export type ShotOutcome = "made" | "missed" | "blocked" | "goal";

export interface ShotMark {
  id: string;
  side: Side;
  x: number;
  y: number;
  outcome: ShotOutcome;
}

const clamp = (value: number, upper: number) =>
  Math.min(Math.max(value, 0), upper);

/**
 * This period's map, or undefined where there's nothing to draw: a league
 * with no surface, a feed with no period yet, or a shootout (a shootout's
 * attempts aren't a period's play and would redraw the same net a dozen
 * times).
 */
export function currentShotMap(
  game: Game,
  plays: PlayItem[],
  allowsShootout: boolean
): ShotMap | undefined {
  const surface =
    game.league === "nba" ? "court" : game.league === "nhl" ? "rink" : undefined;
  if (!surface) return undefined;
  let period: number | undefined;
  for (let i = plays.length - 1; i >= 0 && period === undefined; i--) {
    period = plays[i].period;
  }
  if (period === undefined) return undefined;
  if (allowsShootout && surface === "rink" && period === 5) return undefined;
  const awayId = String(game.awayTeam.team.espnId);
  const inPeriod = plays.filter((p) => p.period === period);
  const side = (play: PlayItem): Side | undefined =>
    play.teamId === undefined ? undefined : play.teamId === awayId ? "away" : "home";

  if (surface === "court") {
    const marks: ShotMark[] = [];
    for (const play of inPeriod) {
      const s = side(play);
      if (!play.isShootingPlay || !play.coordinate || !s) continue;
      const { x: cx, y: cy } = play.coordinate;
      const [x, y] = s === "home" ? [cy, cx] : [94 - cy, 50 - cx];
      marks.push({
        id: play.id,
        side: s,
        x: clamp(x, 94),
        y: clamp(y, 50),
        outcome: play.isScoringPlay ? "made" : "missed",
      });
    }
    return { surface, period, marks };
  }

  const attempts = inPeriod.flatMap((play) => {
    const s = side(play);
    const outcome = hockeyOutcome(play.typeText);
    if (!play.coordinate || !s || !outcome) return [];
    return [{ play, side: s, spot: play.coordinate, outcome }];
  });
  // Which way the away team is shooting this period, by vote: an away
  // attempt right of center or a home attempt left of it says "as drawn".
  // Blocked shots sit out — their spot is the block, which can be anywhere
  // in the zone.
  const vote = attempts
    .filter((a) => a.outcome !== "blocked")
    .reduce(
      (total, a) => total + Math.sign(a.side === "away" ? a.spot.x : -a.spot.x),
      0
    );
  const turned = vote < 0;
  const marks = attempts.map(({ play, side: s, spot, outcome }) => {
    const x = turned ? -spot.x : spot.x;
    const y = turned ? -spot.y : spot.y;
    return {
      id: play.id,
      side: s,
      x: clamp(x + 100, 200),
      y: clamp(42.5 - y, 85),
      outcome,
    };
  });
  return { surface, period, marks };
}

/** ESPN's hockey play types that are shot attempts. Everything else —
 *  faceoffs, hits, giveaways, penalties — isn't drawn. */
export function hockeyOutcome(type: string | undefined): ShotOutcome | undefined {
  switch (type?.toLowerCase()) {
    case "shot":
      return "made";
    case "goal":
      return "goal";
    case "missed":
      return "missed";
    case "blocked":
      return "blocked";
    default:
      return undefined;
  }
}

// MARK: - Team marks

/**
 * A team's end zone or shot mark, as the hex it picked, or undefined for the
 * fallback gray. The primary color unless it would vanish against what's
 * behind it — near-black in dark mode, near-white in light — in which case
 * the alternate, and gray when neither is usable. Court and ice are light in
 * both modes, so their marks always ask with `isDark: false`.
 */
export function teamMarkHex(
  primary: string | undefined,
  alternate: string | undefined,
  isDark: boolean
): string | undefined {
  for (const candidate of [primary, alternate]) {
    const rgb = candidate === undefined ? undefined : hexToRgb(candidate);
    if (!rgb) continue;
    const lum = luminance(rgb);
    if (isDark ? lum >= 0.012 : lum <= 0.8) {
      return candidate!.startsWith("#") ? candidate : `#${candidate}`;
    }
  }
  return undefined;
}

/** ESPN ships colors as bare hex, "970310"; the web's `Team` carries them
 *  with a "#". Anything else that isn't six hex digits is no color at all. */
function hexToRgb(hex: string): [number, number, number] | undefined {
  const digits = hex.startsWith("#") ? hex.slice(1) : hex;
  if (!/^[0-9a-fA-F]{6}$/.test(digits)) return undefined;
  const value = parseInt(digits, 16);
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff].map(
    (c) => c / 255
  ) as [number, number, number];
}

/** WCAG relative luminance. */
function luminance([r, g, b]: [number, number, number]): number {
  const linear = (c: number) =>
    c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
}
