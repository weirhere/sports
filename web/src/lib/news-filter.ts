// Which followed teams For you shows — the web twin of iOS
// `UIStateStore.newsHiddenTeams` (2026-10-19). The sheet's unchecked rows,
// by follow key, in `localStorage`. The follow itself is untouched; a team
// unfollowed later just stops being consulted.

/** The `cfb-hub-` prefix the follow sets use, so the keys sit together. */
export const NEWS_HIDDEN_TEAMS_KEY = "cfb-hub-news-hidden-teams";

type ReadableStorage = Pick<Storage, "getItem">;
type WritableStorage = Pick<Storage, "setItem">;

/** The stored hidden set; empty for anything that isn't a string array.
 *  Every access wrapped: `localStorage` throws outright in some private
 *  modes, and a News tab that can't remember is still a News tab. */
export function readHiddenTeams(storage: ReadableStorage | undefined): Set<string> {
  if (!storage) return new Set();
  try {
    const parsed: unknown = JSON.parse(storage.getItem(NEWS_HIDDEN_TEAMS_KEY) ?? "[]");
    if (!Array.isArray(parsed)) return new Set();
    return new Set(parsed.filter((key): key is string => typeof key === "string"));
  } catch {
    return new Set();
  }
}

export function writeHiddenTeams(
  storage: WritableStorage | undefined,
  hidden: ReadonlySet<string>
): void {
  if (!storage) return;
  try {
    storage.setItem(NEWS_HIDDEN_TEAMS_KEY, JSON.stringify([...hidden].sort()));
  } catch {
    // Quota or blocked storage: the choice lives for this page view only.
  }
}

/** The follows For you shows: everyone followed, less the hidden set.
 *  Order kept, so the caller's sort stands. */
export function visibleFollowKeys(
  keys: readonly string[],
  hidden: ReadonlySet<string>
): string[] {
  return keys.filter((key) => !hidden.has(key));
}
