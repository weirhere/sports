#!/usr/bin/env python3
"""Build coaches.json: each football team's coordinators and QB coach.

ESPN lists head coaches only (E27's probe, 2026-09-27), so the assistants
come from Wikipedia, which is CC BY-SA 4.0 -- the app credits it in
Settings. Two sources, because the two levels keep their staffs in two
places:

- NFL: the team's staff template, `Template:{Team} staff`, one line per
  coach as `*Role – [[Name]]` under `;Offensive coaches`-style headings.
- College (FBS): the season article, `{year} {Team} football team`, whose
  "Coaching staff" section lists `* [[Name]] – ''Role''`. The program's
  own article carries the same list and is the fallback, but it lags a
  hire by weeks, so the season article goes first.

Teams come from ESPN (ids are what the app joins on); a team whose page
can't be found or parsed is reported and left out, never guessed.

Only "important" roles are kept (Andy, 2026-10-03: "OC, DC, QB coach and
other important coaching roles"): coordinators, the assistant head coach
and the quarterbacks coach. Position coaches, analysts, quality control,
strength staff and the front office are dropped -- a Coach card that listed
all twenty would bury the roster under it.

Usage: scripts/build-coaches.py [--season 2026] [--only nfl|college-football]
Writes web/public/coaches.json (served at statside.co/coaches.json) and
sports/Resources/coaches.json (the copy bundled into the app).

Uses `?action=raw` on the article URL rather than the MediaWiki API: the
API rate-limits shared cloud IPs hard (429 on the first request from an
agent sandbox, 2026-10-03), while raw page fetches answer normally. One
request per team, a second apart, with a descriptive User-Agent per
Wikimedia's bot policy.
"""

import argparse
import datetime
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = [ROOT / "web/public/coaches.json", ROOT / "sports/Resources/coaches.json"]
UA = "StatSideCoachBot/1.0 (https://www.statside.co; iamandyweir@gmail.com)"
ESPN = "https://site.api.espn.com/apis"
DELAY = 1.0

# ESPN display names that don't match the Wikipedia article title.
# Add a line when the run reports a miss; the value replaces the team part
# of the title ("{year} {value} football team" / "{value} football").
COLLEGE_TITLE_OVERRIDES = {
    "Hawai'i Rainbow Warriors": "Hawaii Rainbow Warriors",
    "San José State Spartans": "San Jose State Spartans",
    "Miami Hurricanes": "Miami Hurricanes",
    "Miami (OH) RedHawks": "Miami RedHawks",
    "App State Mountaineers": "Appalachian State Mountaineers",
    "UL Monroe Warhawks": "Louisiana–Monroe Warhawks",
    "Louisiana Ragin' Cajuns": "Louisiana Ragin' Cajuns",
    "UMass Minutemen": "UMass Minutemen",
    "Southern Miss Golden Eagles": "Southern Miss Golden Eagles",
    "Florida International Panthers": "FIU Panthers",
    "Sam Houston Bearkats": "Sam Houston Bearkats",
    "UTSA Roadrunners": "UTSA Roadrunners",
}


def get(url, as_json=False):
    # Wikimedia asks bots to identify themselves; ESPN 403s that same
    # User-Agent, so it goes to Wikipedia only.
    headers = {"User-Agent": UA} if "wikipedia.org" in url else {}
    req = urllib.request.Request(url, headers=headers)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                return json.loads(body) if as_json else body
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code == 429 and attempt < 3:
                print(f"  429, backing off: {url}", file=sys.stderr)
                time.sleep(5 * 2 ** attempt)
                continue
            raise
    return None


def wiki_raw(title):
    """The page's wikitext, following one #REDIRECT, or None."""
    for _ in range(2):
        url = "https://en.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")) + "?action=raw"
        text = get(url)
        time.sleep(DELAY)
        if text is None:
            return None, None
        m = re.match(r"\s*#REDIRECT\s*\[\[([^\]#|]+)", text, re.I)
        if not m:
            return text, title
        title = m.group(1).strip()
    return None, None


# --- Teams -----------------------------------------------------------------

def nfl_teams():
    data = get(f"{ESPN}/site/v2/sports/football/nfl/teams?limit=100", as_json=True)
    teams = data["sports"][0]["leagues"][0]["teams"]
    return [(t["team"]["id"], t["team"]["displayName"]) for t in teams]


def fbs_teams():
    data = get(f"{ESPN}/v2/sports/football/college-football/standings?group=80", as_json=True)
    out = {}
    for conf in data.get("children", []):
        for entry in conf.get("standings", {}).get("entries", []):
            t = entry["team"]
            out[t["id"]] = t["displayName"]
    return sorted(out.items(), key=lambda kv: kv[1])


# --- Parsing ---------------------------------------------------------------

# An en or em dash with or without spaces, but a hyphen only with spaces
# around it: "Co-defensive coordinator" and "Abdul-Rahim" are one word.
DASH = r"\s*(?:–|—|&ndash;|&mdash;)\s*|\s+-\s+"


def split_entry(line, name_first=True):
    """One staff line to (name, role), or None.

    Pages write it four ways: `[[Name]] – Role`, `Role – [[Name]]` (NFL
    templates, `name_first=False`), `[[Name]]{{small|Role}}` and
    `[[Name]] (School) 4th year (Role)`.
    """
    line = line.strip().lstrip("*").strip()
    line = re.sub(r"\{\{\s*small\s*\|([^{}]*)\}\}", r" – \1", line, flags=re.I)
    parts = re.split(DASH, line)
    if len(parts) >= 2:
        # The name is the end the page puts it at; everything else is role
        # ("Assistant head coach/defense – Outside linebackers – [[Name]]").
        if name_first:
            name, role = parts[0], " – ".join(parts[1:])
        else:
            name, role = parts[-1], " – ".join(parts[:-1])
        return tidy(name, role)
    if name_first:
        parens = re.findall(r"\(([^()]*)\)", line)
        role = next((p for p in reversed(parens) if re.search(r"coach|coordinator", p, re.I)), None)
        if role:
            return tidy(line.split("(")[0], role)
    return None


def tidy(name, role):
    """`Name (Appalachian State) 4th year` to `Name`; `(role)` to `role`.
    A name with an unclosed parenthesis is a line the split got wrong, and
    is dropped rather than shipped as a person called "Trevor Borland (quality
    control"."""
    name, role = clean(name), clean(role)
    if name.count("(") != name.count(")"):
        return None
    name = re.sub(r"\s*\([^()]*\)", "", name)
    name = re.sub(r"\s+\d+(?:st|nd|rd|th) year\b.*$", "", name, flags=re.I).strip()
    role = role.strip("() ")
    return name, role


def clean(text):
    """Wikitext to plain text: links to their label, templates and refs out."""
    text = re.sub(r"<ref[^>]*/>", "", text)
    text = re.sub(r"<ref[^>]*>.*?</ref>", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"\{\{\s*(?:sortname|sname)\s*\|([^|}]+)\|([^|}]+)[^}]*\}\}", r"\1 \2", text, flags=re.I)
    text = re.sub(r"\{\{[^{}]*\}\}", "", text)
    text = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("''", "").replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", text).strip(" *;:")


def nfl_staff(text):
    staff, section = [], ""
    for line in text.splitlines():
        # Headings come as `;Offensive coaches` or as a bold line.
        if line.startswith(";") or re.match(r"^'{3}[^']+'{3}\s*$", line):
            section = clean(line).lower()
            continue
        if not line.startswith("*") or "coach" not in section:
            continue
        if "strength" in section:
            continue
        entry = split_entry(line, name_first=False)
        if entry:
            staff.append(entry)
    return staff


def college_staff(text):
    """The staff in the roster's footer template.

    `{{American football roster/Footer|…|head_coach=* [[Name]]|asst_coach=
    * [[Name]] – ''Role''…}}`. Some pages put the assistants under
    `head_coach=` too, so both lists are read; the head coach's own line has
    no role and drops out at the dash split.
    """
    start = text.find("{{American football roster/Footer")
    footer = footer_staff(text, start) if start >= 0 else []
    # The footer's head_coach line alone (no assistants) means the page
    # keeps its staff somewhere else.
    return footer if any(role for _, role in footer) else section_staff(text)


def section_staff(text):
    """A "Coaching staff" section, as a wikitable (`| [[Name]] || Role ||…`,
    Alabama) or as a list (`* [[Name]] – Role`)."""
    m = re.search(r"^(=+)\s*(?:Current\s+)?coaching staff\s*\1\s*$", text, re.I | re.M)
    if not m:
        return []
    body = text[m.end():]
    nxt = re.search(r"^=+[^=]", body, re.M)
    body = body[: nxt.start()] if nxt else body
    staff = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("|") and "||" in line:
            cells = [c for c in line.lstrip("|").split("||")]
            if len(cells) >= 2:
                staff.append((clean(cells[0]), clean(re.sub(r"^[^|\[]*\|(?!\|)", "", cells[1]))))
        elif line.startswith("*"):
            entry = split_entry(line)
            if entry:
                staff.append(entry)
    return staff


def footer_staff(text, start):
    staff, param = [], None
    for line in text[start:].splitlines():
        if line.strip().startswith("}}"):
            break
        m = re.match(r"\s*\|\s*([a-z_]+)\s*=", line)
        if m:
            param = m.group(1)
            line = line[m.end():]
        if param not in ("head_coach", "asst_coach") or not line.strip().startswith("*"):
            continue
        entry = split_entry(line)
        if entry:
            staff.append(entry)
    return staff


# --- Which roles, in which order --------------------------------------------

def rank(role):
    """Sort key for a kept role, or None to drop it.

    Coordinators of the three phases, the assistant head coach and the
    quarterbacks coach. Pass- and run-game coordinators are left out: they
    doubled the card's length, and an NFL template can list two identical
    "Pass game coordinator" lines (one per side) with nothing on a phone to
    tell them apart. The head coach is left out because ESPN has them.
    """
    r = role.lower()
    if any(w in r for w in ("analyst", "analysis", "quality control", "graduate", "strength",
                            "director", "intern", "consultant", "advisor", "management")):
        return None

    def phase(side):
        return re.search(rf"(?<!assistant )(?:co-)?{side} coordinator", r) is not None

    if phase("offensive"):
        return 0
    if phase("defensive"):
        return 1
    if phase("special teams"):
        return 2
    if "assistant head coach" in r or "associate head coach" in r:
        return 3
    if "quarterback" in r and not r.startswith("assistant"):
        return 4
    return None


def role_label(role):
    """'Quarterbacks' alone reads as a position group, so it gains 'coach'."""
    # One spelling per role: pages disagree on "Offensive Coordinator" vs
    # "Offensive coordinator" and on spaces around the slash.
    role = re.sub(r"\s*/\s*", "/", role.strip()).lower()
    if role in ("quarterbacks", "quarterback"):
        role = "quarterbacks coach"
    return role[:1].upper() + role[1:]


def keep(staff):
    seen, kept = set(), []
    for name, role in staff:
        k = rank(role)
        if k is None or not re.search(r"[A-Za-z]{2}", name) or re.search(r"[\[\]{}|=<>]", name + role) or name in seen:
            continue
        seen.add(name)
        kept.append((k, name, role_label(role)))
    kept.sort(key=lambda t: t[0])  # stable: Wikipedia's order within a rank
    return [{"name": n, "role": r} for _, n, r in kept]


# --- Main ------------------------------------------------------------------

def build_nfl(misses):
    out = {}
    for team_id, name in nfl_teams():
        title = f"Template:{name} staff"
        text, final = wiki_raw(title)
        staff = keep(nfl_staff(text)) if text else []
        if staff:
            out[team_id] = {"source": "https://en.wikipedia.org/wiki/" + final.replace(" ", "_"), "staff": staff}
        else:
            misses.append(f"nfl {team_id} {name}: {title}")
        print(f"nfl {name}: {len(staff)}", file=sys.stderr)
    return out


def build_college(season, misses):
    out = {}
    for team_id, name in fbs_teams():
        base = COLLEGE_TITLE_OVERRIDES.get(name, name)
        staff, source = [], None
        for title in (f"{season} {base} football team", f"{base} football"):
            text, final = wiki_raw(title)
            staff = keep(college_staff(text)) if text else []
            if staff:
                source = final
                break
        if staff:
            out[team_id] = {"source": "https://en.wikipedia.org/wiki/" + source.replace(" ", "_"), "staff": staff}
        else:
            misses.append(f"college-football {team_id} {name}: {season} {base} football team")
        print(f"college {name}: {len(staff)}", file=sys.stderr)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--season", type=int, default=datetime.date.today().year)
    ap.add_argument("--only", choices=["nfl", "college-football"])
    args = ap.parse_args()

    previous_doc = json.loads(OUTPUTS[0].read_text()) if OUTPUTS[0].exists() else {}
    previous = previous_doc.get("leagues", {})

    misses = []
    leagues = dict(previous)
    if args.only in (None, "nfl"):
        leagues["nfl"] = build_nfl(misses)
    if args.only in (None, "college-football"):
        leagues["college-football"] = build_college(args.season, misses)

    doc = {
        "version": 1,
        # Only moves when a staff did, so a quiet week makes no diff and the
        # weekly job opens no PR.
        "updated": previous_doc.get("updated") if leagues == previous
                   else datetime.date.today().isoformat(),
        "license": "Text from Wikipedia, CC BY-SA 4.0",
        "leagues": leagues,
    }
    payload = json.dumps(doc, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    for path in OUTPUTS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload)

    counts = {k: len(v) for k, v in leagues.items()}
    print(f"wrote {counts}; {len(misses)} misses", file=sys.stderr)
    for m in misses:
        print("  miss:", m, file=sys.stderr)


if __name__ == "__main__":
    main()
