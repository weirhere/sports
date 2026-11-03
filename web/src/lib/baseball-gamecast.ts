// Where a live baseball game stands, read off ESPN's play feed — the web twin
// of iOS `BaseballDiamond` (StatSideShared/Models/BaseballGamecast.swift,
// 2026-11-03). See there for why each field is read the way it is: runners
// describe the bases *after* a play, and outs are stamped per at-bat with the
// outs it ended on, so they come from the latest finished at-bat.

import type { GamecastContent } from "@/lib/gamecast";
import type { BoxScoreTeam, PlayItem } from "@/lib/types";

export interface BaseballDiamond {
  inning?: number;
  half?: PlayItem["half"];
  onFirst: boolean;
  onSecond: boolean;
  onThird: boolean;
  outs: number;
  balls?: number;
  strikes?: number;
  batterId?: string;
  pitcherId?: string;
  /** The side batting this half: the away team in the top. */
  battingSide?: "away" | "home";
  /** "96 mph Four-seam FB". */
  lastPitch?: string;
  lastResult?: string;
  playId?: string;
}

export function isBreak(diamond: BaseballDiamond): boolean {
  return diamond.half === "middle" || diamond.half === "end";
}

function ordinal(n: number): string {
  if ([11, 12, 13].includes(n % 100)) return `${n}th`;
  switch (n % 10) {
    case 1:
      return `${n}st`;
    case 2:
      return `${n}nd`;
    case 3:
      return `${n}rd`;
    default:
      return `${n}th`;
  }
}

/** "Top 5th", "Mid 5th" — ESPN's status-line spelling. */
export function inningText(diamond: BaseballDiamond): string | undefined {
  if (diamond.inning === undefined || diamond.half === undefined) return undefined;
  const word = { top: "Top", bottom: "Bot", middle: "Mid", end: "End" }[diamond.half];
  return `${word} ${ordinal(diamond.inning)}`;
}

/** "96 mph Four-seam FB", the speed where ESPN has one. */
export function pitchLine(play: PlayItem): string | undefined {
  const state = play.baseball;
  if (!state?.pitchType) return undefined;
  return state.pitchVelocity && state.pitchVelocity > 0
    ? `${state.pitchVelocity} mph ${state.pitchType}`
    : state.pitchType;
}

/** The state after the latest play, or undefined for a feed with no baseball
 *  in it or nothing played yet. */
export function currentDiamond(plays: readonly PlayItem[]): BaseballDiamond | undefined {
  const withState = plays.filter((p) => p.baseball !== undefined);
  const last = withState[withState.length - 1];
  if (!last?.baseball) return undefined;
  const half = last.half;
  const inning = last.period;
  const inHalf = withState.filter((p) => p.period === inning && p.half === half);
  const brk = half === "middle" || half === "end";
  const findLast = (pred: (p: PlayItem) => boolean) => {
    for (let i = inHalf.length - 1; i >= 0; i--) if (pred(inHalf[i])) return inHalf[i];
    return undefined;
  };
  const finished = findLast(
    (p) => p.baseball?.kind === "play-result" || p.baseball?.kind === "end-batterpitcher"
  );
  const matchup = findLast((p) => !!(p.baseball?.batterId || p.baseball?.pitcherId));
  const pitch = findLast((p) => !!p.baseball?.pitchType);
  let result: PlayItem | undefined;
  for (let i = withState.length - 1; i >= 0 && !result; i--) {
    if (withState[i].baseball?.kind === "play-result") result = withState[i];
  }
  const outs = brk ? 0 : (finished?.baseball?.outs ?? 0);
  return {
    inning,
    half,
    onFirst: !brk && last.baseball.onFirst,
    onSecond: !brk && last.baseball.onSecond,
    onThird: !brk && last.baseball.onThird,
    outs: Math.min(Math.max(outs, 0), 3),
    balls: brk ? undefined : last.baseball.balls,
    strikes: brk ? undefined : last.baseball.strikes,
    batterId: brk ? undefined : matchup?.baseball?.batterId,
    pitcherId: brk ? undefined : matchup?.baseball?.pitcherId,
    battingSide: half === "top" ? "away" : half === "bottom" ? "home" : undefined,
    lastPitch: brk || !pitch ? undefined : pitchLine(pitch),
    lastResult: result?.text,
    playId: last.id,
  };
}

/** The Plays tab for baseball: one row per at-bat result, grouped by
 *  half-inning, newest half first (iOS `PeriodPlayList.segments`). Plays
 *  inside a half stay in feed order — the list's row reverses them, as it
 *  does every league's. */
export function halfInningSegments(
  plays: readonly PlayItem[]
): { period?: number; half?: PlayItem["half"]; plays: PlayItem[] }[] {
  const order: string[] = [];
  const bySegment = new Map<string, { period?: number; half?: PlayItem["half"]; plays: PlayItem[] }>();
  for (const play of plays) {
    if (play.baseball && play.baseball.kind !== "play-result") continue;
    const key = `${play.period ?? ""}|${play.half ?? ""}`;
    let segment = bySegment.get(key);
    if (!segment) {
      segment = { period: play.period, half: play.half, plays: [] };
      bySegment.set(key, segment);
      order.push(key);
    }
    segment.plays.push(play);
  }
  return order.reverse().map((key) => bySegment.get(key)!);
}

/** Every athlete the box score names, by id — what a baseball play's batter
 *  and pitcher ids resolve against. */
export function athleteNames(boxScore: readonly BoxScoreTeam[] | undefined): Map<string, string> {
  const names = new Map<string, string>();
  for (const team of boxScore ?? []) {
    for (const category of team.categories) {
      for (const player of category.players) {
        if (player.athleteId) names.set(player.athleteId, player.name);
      }
    }
  }
  return names;
}

/** Baseball's card (iOS `GamecastContent.baseball`): Count · Outs · Pitch,
 *  the matchup and the last result beneath. */
export function baseballGamecast(
  diamond: BaseballDiamond,
  names: Map<string, string>
): GamecastContent {
  const brk = isBreak(diamond);
  const batter = diamond.batterId ? names.get(diamond.batterId) : undefined;
  const pitcher = diamond.pitcherId ? names.get(diamond.pitcherId) : undefined;
  const count =
    diamond.balls !== undefined && diamond.strikes !== undefined
      ? `${diamond.balls}-${diamond.strikes}`
      : undefined;
  const matchup =
    batter && pitcher
      ? `${batter} vs ${pitcher}`
      : batter
        ? `${batter} batting`
        : pitcher
          ? `${pitcher} pitching`
          : "Last play";
  const inning = inningText(diamond);
  const spoken: string[] = inning ? [inning] : [];
  if (!brk) {
    const bases = (
      [
        [diamond.onFirst, "first"],
        [diamond.onSecond, "second"],
        [diamond.onThird, "third"],
      ] as const
    )
      .filter(([on]) => on)
      .map(([, name]) => name);
    spoken.push(bases.length === 0 ? "bases empty" : `runners on ${bases.join(" and ")}`);
    spoken.push(diamond.outs === 1 ? "1 out" : `${diamond.outs} outs`);
    if (count) spoken.push(`count ${count}`);
    if (batter || pitcher) spoken.push(matchup);
  }
  if (diamond.lastResult) spoken.push(diamond.lastResult);
  return {
    slots: [
      { label: "Count", value: count },
      { label: "Outs", value: brk ? undefined : String(diamond.outs) },
      { label: "Pitch", value: diamond.lastPitch },
    ],
    lastPlayLabel: brk ? "Last play" : matchup,
    lastPlayClock: inning,
    lastPlayText: diamond.lastResult,
    accessibilitySummary: spoken.join(", "),
  };
}
