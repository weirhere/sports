// Dark-mode logo derivation — a faithful port of the iOS app's
// `URL.darkTeamLogoVariant` (StatSideShared/Models/LogoVariant.swift).
//
// ESPN publishes dark-mode team marks alongside the defaults
// (`/i/teamlogos/ncaa/500-dark/` next to `/i/teamlogos/ncaa/500/`), but the
// scoreboard payload carries only the light URL — so the dark one is
// derived, never decoded. Conference marks (`ncaa_conf`) and GUID-based
// logo URLs have no verified dark twin and deliberately don't match;
// callers treat null as "use the light logo".

const LIGHT_PATH = "/i/teamlogos/ncaa/500/";
const DARK_PATH = "/i/teamlogos/ncaa/500-dark/";

export function darkTeamLogoVariant(url: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (!parsed.hostname.endsWith("espncdn.com")) return null;
  if (!parsed.pathname.includes(LIGHT_PATH)) return null;
  return url.replace(LIGHT_PATH, DARK_PATH);
}
