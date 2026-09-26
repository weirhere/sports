// "Find a league" — the Leagues hub's filter (iOS `TablesScreen`'s
// `visibleGroups` / `visibleFollowedRows`, 2026-09-21).
//
// Pure, and shaped generically so the hub hands it whatever rows it renders:
// the matching rule is the whole port, and the rendering is the hub's.

/** The query as the hub reads it: surrounding whitespace never matters. */
export function hubQuery(raw: string): string {
  return raw.trim();
}

/**
 * Case-insensitive containment — the web's `localizedCaseInsensitiveContains`.
 * An empty needle matches everything, so an untouched field filters nothing.
 */
export function matchesQuery(haystack: string, query: string): boolean {
  const needle = hubQuery(query).toLocaleLowerCase();
  if (needle.length === 0) return true;
  return haystack.toLocaleLowerCase().includes(needle);
}

/** One accordion's worth: a league, and the rows inside it. */
export interface HubGroup<Row> {
  title: string;
  rows: Row[];
}

/**
 * The groups the query leaves standing.
 *
 * A league survives if its **own** title matches — "NFL" hands back the
 * whole NFL card, every row in it, because you asked for the league and not
 * one table inside it. Otherwise it survives if any of its rows match, and
 * then only those rows show. A league with neither is gone.
 */
export function filterHubGroups<Row, Group extends HubGroup<Row>>(
  groups: readonly Group[],
  query: string,
  rowTitle: (row: Row) => string
): Group[] {
  if (hubQuery(query).length === 0) return [...groups];
  const kept: Group[] = [];
  for (const group of groups) {
    if (matchesQuery(group.title, query)) {
      kept.push(group);
      continue;
    }
    const rows = group.rows.filter((row) => matchesQuery(rowTitle(row), query));
    if (rows.length > 0) kept.push({ ...group, rows });
  }
  return kept;
}

/**
 * Following, narrowed by the same query — Andy's ask was that it filter
 * both lists, not just the one below it.
 */
export function filterFollowed<Row>(
  rows: readonly Row[],
  query: string,
  rowTitle: (row: Row) => string
): Row[] {
  if (hubQuery(query).length === 0) return [...rows];
  return rows.filter((row) => matchesQuery(rowTitle(row), query));
}
