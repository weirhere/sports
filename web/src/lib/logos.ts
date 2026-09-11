// Dark-mode logo derivation — a port of the iOS app's
// `URL.darkTeamLogoVariant` (StatSideShared/Models/LogoVariant.swift).
//
// ESPN publishes dark-mode team marks alongside the defaults
// (`/i/teamlogos/nfl/500-dark/ne.png` next to `/500/ne.png`), but no payload
// carries the dark URL — so it is derived, never decoded.
//
// The bucket is the league's, not a constant: `ncaa` for college football,
// `nfl` / `nba` / `nhl` for the others. All four verified 200 on 2026-09-09,
// including the NHL's nested `500-dark/scoreboard/` path.
//
// **Conference marks deliberately don't match.** ESPN serves no
// `ncaa_conf/500-dark`, and probing every plausible spelling for the NBA's
// and NHL's found none either — a conference header rides a light backing
// disc in dark mode instead. Callers treat null as "use the light logo".

const TEAM_BUCKETS = ["ncaa", "nfl", "nba", "nhl"] as const;

/**
 * Matches `/i/teamlogos/<team bucket>/500/` and captures it, so
 * `ncaa_conf/500/` — which shares the `/500/` shape — can't slip through.
 */
const LIGHT_PATH = new RegExp(
  `(/i/teamlogos/(?:${TEAM_BUCKETS.join("|")})/500)/`
);

export function darkTeamLogoVariant(url: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (!parsed.hostname.endsWith("espncdn.com")) return null;
  if (!LIGHT_PATH.test(parsed.pathname)) return null;
  return url.replace(LIGHT_PATH, "$1-dark/");
}

/**
 * The same headshot, asked for at row size — a port of iOS
 * `URL.headshotThumbnail`.
 *
 * ESPN's roster payload links `/i/headshots/…/full/{id}.png`, a 600×436 PNG
 * weighing ~200 KB. A college football roster is 100 players, so a Roster tab
 * rendered off those URLs pulls ~20 MB to fill a screenful of 36px discs. The
 * CDN's own resizer takes the file down to ~19 KB — verified live 2026-09-11:
 * 219,372 bytes → 19,559 — and 110px on the short side is still sharp in a
 * 36px disc on a 2× display.
 *
 * The `?w=` parameters the plain path accepts are ignored (the full image
 * comes back at full size), so the combiner is the only way to ask. A player
 * with no photo 404s cleanly, which the row treats as "no headshot".
 *
 * Null for any URL that isn't an ESPN headshot — callers fall back to the
 * href they were given.
 */
export function headshotThumbnail(url: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (!parsed.hostname.endsWith("espncdn.com")) return null;
  if (!parsed.pathname.includes("/i/headshots/")) return null;
  return `https://a.espncdn.com/combiner/i?img=${parsed.pathname}&w=150&h=110`;
}
