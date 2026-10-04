#!/usr/bin/env python3
"""Build team-colors.json: every team's ESPN primary color, by follow key.

A team page's light-mode header paints in the team's color (2026-09-27),
but the only live payload carrying it is the team's schedule, so every
first visit opened white and turned team-colored when the request landed
(Andy, 2026-10-03: "there is always a delay in the background turning the
appropriate color"). The colors barely move from one season to the next,
so the app ships them and paints the first frame; a live color still wins
when one arrives.

One ESPN `/teams?limit=1000` request per league. College football's is
~1.8 MB, which is why this runs here rather than at launch. A team ESPN
sends without a color is left out, and its page falls back to the live
request as before.

Usage: scripts/build-team-colors.py
Writes sports/Resources/team-colors.json as {"<league>:<teamId>": "<hex>"},
the app's `FollowKey` spelling.
"""

import json
import pathlib
import sys
import urllib.request

LEAGUES = {
    "cfb": "football/college-football",
    "nfl": "football/nfl",
    "nba": "basketball/nba",
    "nhl": "hockey/nhl",
}

OUT = pathlib.Path(__file__).resolve().parent.parent / "sports" / "Resources" / "team-colors.json"


def teams(path):
    url = f"https://site.api.espn.com/apis/site/v2/sports/{path}/teams?limit=1000"
    request = urllib.request.Request(url, headers={"User-Agent": "StatSide build-team-colors"})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = json.load(response)
    for league in payload.get("sports", [{}])[0].get("leagues", []):
        for entry in league.get("teams", []):
            yield entry.get("team", {})


def main():
    colors = {}
    for key, path in LEAGUES.items():
        found = 0
        for team in teams(path):
            team_id, color = team.get("id"), (team.get("color") or "").strip().lower()
            if team_id and len(color) == 6:
                colors[f"{key}:{team_id}"] = color
                found += 1
        print(f"{key}: {found} colors", file=sys.stderr)
    OUT.write_text(json.dumps(colors, sort_keys=True, separators=(",", ":")) + "\n")
    print(f"wrote {len(colors)} colors to {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
