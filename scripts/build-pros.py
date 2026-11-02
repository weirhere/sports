#!/usr/bin/env python3
"""Build pros.json: each school's players now in the NFL, NBA and NHL.

The reverse of the player page's College row (2026-11-02). ESPN puts
`college: {id, name, shortName, abbrev, mascot}` on every athlete of a pro
team's `/teams/{id}/roster` (every NFL and NBA player, about half an NHL
roster), so the index is a walk of all 94 pro rosters grouped by that id.
That walk is ~18 MB of JSON, which is why it runs here, weekly, and not on
a phone: Andy's call, the same day, `coaches.json`'s pattern.

ESPN's college id is the school id, the same value as that school's college
football team id (UNC 153, Florida State 52, UMass 113), so the app keys
its Pros tab by the team page's own id. A college id that names no FBS or
FCS team is reported (a school without football, most of them for the NBA)
and still written: nothing in the app asks for it, and nothing is guessed.

Usage: scripts/build-pros.py
Writes web/public/pros.json (served at statside.co/pros.json) and
sports/Resources/pros.json (the copy bundled into the app). Exits non-zero
and writes nothing when a league comes back short, so a bad ESPN day can't
ship an empty index.
"""

import datetime
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = [ROOT / "web/public/pros.json", ROOT / "sports/Resources/pros.json"]
SITE = "https://site.api.espn.com/apis/site/v2/sports"
DELAY = 0.3

# (sport, league path segment, fewest teams, fewest athletes with a college)
# that still count as a whole answer. Measured 2026-11-02: 32 NFL teams with
# ~2,600 players (all with a college), 30 NBA with ~510 (~460), 32 NHL with
# ~800 (~300).
LEAGUES = [
    ("football", "nfl", 32, 2000),
    ("basketball", "nba", 30, 300),
    ("hockey", "nhl", 32, 150),
]


def get(url):
    # No User-Agent of our own: `site.api.espn.com` answers 403 to a browser
    # or a descriptive one (ARCHITECTURE.md § Athletes), and urllib's default
    # is what `build-coaches.py` has always sent it.
    req = urllib.request.Request(url)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code in (429, 500, 502, 503) and attempt < 3:
                print(f"  {e.code}, backing off: {url}", file=sys.stderr)
                time.sleep(5 * 2 ** attempt)
                continue
            raise
        except urllib.error.URLError:
            if attempt < 3:
                time.sleep(5 * 2 ** attempt)
                continue
            raise
    return None


def teams(sport, league):
    data = get(f"{SITE}/{sport}/{league}/teams?limit=100") or {}
    out = []
    for league_doc in data.get("sports", [{}])[0].get("leagues", []):
        for entry in league_doc.get("teams", []):
            team = entry.get("team", {})
            if team.get("id"):
                out.append(team["id"])
    return out


def athletes(roster):
    """Both of ESPN's roster shapes: grouped `[{position, items}]` (NFL,
    NHL) and the NBA's flat list of athletes."""
    for element in roster.get("athletes", []) or []:
        if isinstance(element, dict) and "items" in element:
            yield from element.get("items") or []
        elif isinstance(element, dict):
            yield element


def entry(athlete, league, team_id):
    athlete_id = athlete.get("id")
    name = athlete.get("displayName") or athlete.get("fullName")
    if not athlete_id or not name:
        return None
    position = athlete.get("position") or {}
    out = {
        "league": league,
        "athleteId": str(athlete_id),
        "name": name,
        "teamId": str(team_id),
        "position": position.get("abbreviation"),
        "positionName": position.get("displayName") or position.get("name"),
        "jersey": athlete.get("jersey") or None,
        "headshot": (athlete.get("headshot") or {}).get("href"),
    }
    return {k: v for k, v in out.items() if v}


def college_football_ids():
    """FBS (group 80) and FCS (group 81) team ids: what a Pros tab can be
    on. Only used to report misses."""
    ids = set()
    for group in (80, 81):
        data = get(f"https://site.api.espn.com/apis/v2/sports/football/college-football/standings?group={group}") or {}
        stack = [data]
        while stack:
            node = stack.pop()
            stack.extend(node.get("children", []))
            for row in node.get("standings", {}).get("entries", []):
                team_id = row.get("team", {}).get("id")
                if team_id:
                    ids.add(str(team_id))
    return ids


def main():
    colleges = {}
    names = {}
    short = []
    for sport, league, min_teams, min_athletes in LEAGUES:
        team_ids = teams(sport, league)
        found = 0
        for team_id in team_ids:
            roster = get(f"{SITE}/{sport}/{league}/teams/{team_id}/roster") or {}
            time.sleep(DELAY)
            for athlete in athletes(roster):
                college = athlete.get("college") or {}
                college_id = college.get("id")
                row = entry(athlete, league, team_id)
                if not college_id or not row:
                    continue
                colleges.setdefault(str(college_id), []).append(row)
                names[str(college_id)] = college.get("name") or college.get("shortName")
                found += 1
        print(f"{league}: {len(team_ids)} teams, {found} players with a college", file=sys.stderr)
        if len(team_ids) < min_teams or found < min_athletes:
            short.append(f"{league} ({len(team_ids)} teams, {found} players)")

    if short:
        print("refusing to write, short answer from: " + ", ".join(short), file=sys.stderr)
        sys.exit(1)

    league_order = {league: i for i, (_, league, _, _) in enumerate(LEAGUES)}
    for rows in colleges.values():
        rows.sort(key=lambda r: (league_order[r["league"]], r["name"], r["athleteId"]))

    cfb = college_football_ids()
    misses = sorted((cid for cid in colleges if cid not in cfb), key=lambda c: -len(colleges[c]))
    print(f"{len(colleges)} colleges; {len(misses)} name no FBS/FCS team "
          f"({sum(len(colleges[c]) for c in misses)} players)", file=sys.stderr)
    for cid in misses[:15]:
        print(f"  miss: {cid} {names.get(cid)} ({len(colleges[cid])})", file=sys.stderr)

    previous_doc = json.loads(OUTPUTS[0].read_text()) if OUTPUTS[0].exists() else {}
    doc = {
        "version": 1,
        # Only moves when a roster did, so a quiet week makes no diff and the
        # weekly job opens no PR.
        "updated": previous_doc.get("updated") if previous_doc.get("colleges") == colleges
                   else datetime.date.today().isoformat(),
        "colleges": colleges,
    }
    payload = json.dumps(doc, indent=None, separators=(",", ":"), ensure_ascii=False, sort_keys=True)
    # One school per line: compact, and a week's diff still reads per school.
    lines = ["{" + f'"updated":{json.dumps(doc["updated"])},"version":1,"colleges":{{']
    keys = sorted(colleges, key=int)
    for i, cid in enumerate(keys):
        sep = "," if i < len(keys) - 1 else ""
        lines.append(f"{json.dumps(cid)}:{json.dumps(colleges[cid], ensure_ascii=False, sort_keys=True, separators=(',', ':'))}{sep}")
    lines.append("}}")
    payload = "\n".join(lines) + "\n"
    json.loads(payload)  # the hand-joined form must still be one document
    for path in OUTPUTS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload)
    print(f"wrote {len(payload) // 1024} KB to {', '.join(str(p.relative_to(ROOT)) for p in OUTPUTS)}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
