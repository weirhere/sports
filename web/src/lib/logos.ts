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
