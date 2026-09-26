// How a team is named wherever it is listed — iOS `FollowedTeamCard`,
// `TeamFollowRow` and the team page hero (2026-09-21).
//
// A team reads by its **full name** — "Ohio State Buckeyes", "Dallas
// Cowboys" — with `LEAGUE • Conference` under it. The nickname left the
// subtitle and joined the name, where it belongs to the team rather than
// competing with the league; the league leads the subtitle because it does
// the disambiguation the conference alone can't ("Eastern" is the
// Lightning's and the Bucks').

import { conferenceName, divisionForTeamId } from "./conferences";
import { displayName, shortName } from "./leagues";
import type { Team } from "./types";

/**
 * The app's one team name: location and nickname, as ESPN's own
 * `displayName` spells it. A team with no nickname — an FCS visitor ESPN
 * knows little about — is its location alone.
 */
export function teamFullName(team: Pick<Team, "school" | "name">): string {
  return [team.school, team.name].filter(Boolean).join(" ");
}

/**
 * The group the team plays in, unprefixed: the conference, or for the NFL
 * the division — the directory files NFL teams under their conference, so
 * the team's own id would only ever say AFC or NFC.
 */
function rawGroupName(team: Team): string | undefined {
  if (team.league === "nfl") {
    const division = divisionForTeamId(team.id, "nfl");
    if (division !== undefined) return conferenceName(division, "nfl");
  }
  const id = Number(team.conferenceId);
  if (!Number.isInteger(id)) return undefined;
  const name = conferenceName(id, team.league);
  return name === "Other" ? undefined : name;
}

/**
 * "NCAAF • SEC", "NBA • Eastern", "NFL • NFC East".
 *
 * Falls back to the league alone rather than a trailing bullet: an FCS
 * visitor carries no conference we know. A group that already names its
 * league isn't prefixed twice.
 */
export function teamSubtitle(team: Team): string {
  const league = shortName(team.league);
  const group = rawGroupName(team);
  if (!group) return league;
  return group.toLowerCase().includes(league.toLowerCase())
    ? group
    : `${league} • ${group}`;
}

/**
 * The row's one spoken sentence: "Ohio State Buckeyes, College Football
 * Big Ten". The spoken league is the phrase, not the initialism a screen
 * reader would spell out letter by letter (2026-09-21), and the bullet is
 * typography, not a word.
 */
export function teamSpokenLabel(team: Team): string {
  const name = teamFullName(team);
  const group = rawGroupName(team);
  const league = shortName(team.league);
  if (group && group.toLowerCase().includes(league.toLowerCase())) {
    return `${name}, ${group}`;
  }
  return [name, [displayName(team.league), group].filter(Boolean).join(" ")].join(", ");
}
