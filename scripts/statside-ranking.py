#!/usr/bin/env python3
"""The StatSide ranking: FBS ranked two-thirds on résumé, one-third on performance.

The system is the ranking proposal Andy adopted on 2026-10-27 ("College
Football Ranking System -- Initial Proposal"). It keeps two scores visible
and combines them only at the end:

Résumé -- what a team has accomplished against its schedule. How likely is a
fixed benchmark team, as strong as the 90th-percentile FBS team, to match or
beat this team's record against this team's exact schedule, with home, away
and neutral counted? The less likely, the better. The whole probability is
used (a Poisson-binomial over the games), not wins minus expected wins. The
opponents' strength behind it is the average of two ratings. One is an
opponent-adjusted, capped scoring margin fit to every Division I game
(`fit_ratings`):

    capped margin(home) = r_home - r_away + HFA      (HFA 0 at neutral sites)

The other is the performance rating below.

Performance -- how well a team has actually played, read from play-by-play.
Offense and defense are measured on yards per play, success rate,
explosive-play rate, points per meaningful possession and points per red-zone
trip, each adjusted for the defenses or offenses actually faced. Special
teams are measured on punts, kickoffs and returns against the field position
expected from where the kick was made, field goals against the expected makes
at each distance, and extra points. All of it is in points per game against
an average FBS team on a neutral field.

Every rating is a number, not a rank position. Each is solved iteratively
until it settles and pulled toward its group's average by phantom games, so
thin early-season evidence stays near average. Each is refit from scratch on
every run, so earlier opponents are re-rated as their seasons play out.
Conference comparisons are derived from the team ratings afterward.
docs/statside-ranking.md has the definitions, the weights and the backtest
behind every constant below.

Usage:
  scripts/statside-ranking.py                       # this season, table
  scripts/statside-ranking.py --season 2025 --through-week 10
  scripts/statside-ranking.py --json out.json
  scripts/statside-ranking.py --notion              # write Notion columns
  scripts/statside-ranking.py --season 2025 --backtest

Game summaries (the play-by-play) are cached under ~/Library/Caches/StatSide.
STATSIDE_CACHE overrides the location. A finished game never changes, and a
season is about 800 of them.

--notion needs NOTION_TOKEN: an internal integration that the College
Football Teams 2026 database is shared with. Rows are matched by the ESPN
team id in the database's ESPN url, then by title. A team that matches
neither is reported, never guessed. The proposal publishes from week four,
so --notion refuses earlier weeks unless --force is given.

--backtest refits every week of a past season on only the games played by
then, predicts the next week's winners with each rating, and grids the
constants by Brier score. It then compares the end-of-season rankings with
ESPN's Strength of Record, ESPN's FPI and the committee's final ranking.
"""

import argparse
import collections
import datetime
import gzip
import json
import math
import os
import re
import statistics
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

SITE = "https://site.api.espn.com/apis/site/v2/sports/football/college-football"
CORE = "https://sports.core.api.espn.com/v2/sports/football/leagues/college-football"
FPI = "https://site.web.api.espn.com/apis/fitt/v3/sports/football/college-football/powerindex"
NOTION_DATA_SOURCE = "0613b72e-4ad6-4ed4-9dce-1d90a675ca0d"
NOTION_DATABASE = "bb7db8c801a14cd199b7e7c6b164c4a9"
NOTION_CONFERENCE_PAGE = "407f8e9f-c2eb-8153-ba07-c66709c9dcaf"  # "StatSide conference ratings"
CACHE = os.environ.get("STATSIDE_CACHE") or os.path.expanduser("~/Library/Caches/StatSide/ranking")

# ESPN's FBS conference ids. A team counts as FBS when its scoreboard entry
# carries one of these ids.
FBS_CONFERENCES = {
    "151": "American", "1": "ACC", "4": "Big 12", "5": "Big Ten", "12": "Conference USA",
    "18": "FBS Independents", "15": "MAC", "17": "Mountain West", "9": "Pac-12",
    "8": "SEC", "37": "Sun Belt",
}
LIMIT = 300

# The margin rating's constants, tuned by --backtest on 2024 and 2025.
# SIGMA is the spread of a game's margin around the rating gap, which turns
# a gap into a win probability. Uncapped margins with lighter shrinkage
# predicted a hair better (Brier 0.179 vs 0.182 in 2025, 0.189 vs 0.191 in
# 2024) but picked fewer winners. The cap keeps garbage time out, and K = 1
# stops week-four ratings from swinging.
CAP = 35
K = 1.0
SIGMA = 16.0

BENCHMARKS = {"high": 0.90, "mid": 0.50, "low": 0.25}

# Performance. Offense and defense are each a weighted sum of five
# opponent-adjusted stats, each first standardized across FBS. Red zone
# gets modest weight because a team gets few trips, and points per
# possession less than the per-play stats because it partly re-counts them.
# A regression of game margins onto the two sums then scales them into
# points. Explosive plays are runs of 12+ yards and passes of 16+.
#
# UNIT_K and ST_K are the phantom games of shrinkage for each stat and for
# special teams. Special teams are noisy week to week, so they shrink
# harder. The backtest picked them, and PERFORMANCE_SIGMA with them: the
# performance gap spreads less than the margin gap does. On its own,
# performance predicts next week about as well as the margin rating
# (Brier 0.185 vs 0.182 in 2025, 0.189 vs 0.191 in 2024). Averaging the
# two beats either one in both seasons.
WEIGHTS = {"ypp": 0.25, "success": 0.30, "explosive": 0.15, "points": 0.20, "red_zone": 0.10}
STATS = {  # stat: (numerator, denominator) in a team-game's offense line
    "ypp": ("yards", "plays"), "success": ("success", "plays"),
    "explosive": ("explosive", "plays"), "points": ("points", "drives"),
    "red_zone": ("red_zone", "trips"),
}
EXPLOSIVE = {"run": 12, "pass": 16}
UNIT_K = 1.0
ST_K = 6.0
PERFORMANCE_SIGMA = 14.0
RESUME_WEIGHT = 2 / 3
PUBLISH_FROM_WEEK = 4

# What the résumé's win probabilities read as each opponent's strength:
# "blend" (the margin rating averaged with performance) or "margin" alone.
# The blend predicted next week better than either one in 2024 and 2025
# (Brier 0.1815 vs 0.1824, 0.1879 vs 0.1907). It also brought the résumé
# closer to the committee's top 25 and to ESPN's SOR. Andy adopted it on
# 2026-10-28. BLEND_SIGMA is the blend's own spread, from the same grid.
RESUME_STRENGTH = "blend"
BLEND_SIGMA = 14.0


def fetch(url):
    request = urllib.request.Request(url, headers={
        "User-Agent": "StatSide ranking script", "Accept-Encoding": "gzip"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
                if response.headers.get("Content-Encoding") == "gzip":
                    body = gzip.decompress(body)
                return json.loads(body)
        except Exception as error:  # noqa: BLE001 -- retried, then reported
            if attempt == 2:
                raise RuntimeError(f"{url}: {error}") from error
            time.sleep(1 + attempt)


# --- Games -------------------------------------------------------------------


def season_games(season, seasontype=2, weeks=range(1, 17)):
    """Every completed Division I game: FBS (groups=80, which brings their
    FCS opponents along) and FCS-vs-FCS (groups=81), deduped by event id.
    Returns (games, fbs_ids, names, conferences)."""
    games = {}
    fbs_ids = set()
    names = {}
    conferences = {}
    for week in weeks:
        for group in ("80", "81"):
            url = (f"{SITE}/scoreboard?groups={group}&limit={LIMIT}&week={week}"
                   f"&seasontype={seasontype}&dates={season}")
            events = fetch(url).get("events") or []
            if len(events) >= LIMIT:
                print(f"warning: week {week} group {group} came back at the {LIMIT} limit; "
                      "games may be missing", file=sys.stderr)
            for event in events:
                game = parse_game(event, week, seasontype, fbs_ids, names, conferences)
                if game:
                    games[game["id"]] = game
    return list(games.values()), fbs_ids, names, conferences


def parse_game(event, week, seasontype, fbs_ids, names, conferences):
    competition = (event.get("competitions") or [{}])[0]
    if not ((competition.get("status") or {}).get("type") or {}).get("completed"):
        return None
    sides = {}
    for competitor in competition.get("competitors") or []:
        team = competitor.get("team") or {}
        team_id = team.get("id")
        try:
            score = int(competitor.get("score"))
        except (TypeError, ValueError):
            return None
        if not team_id or competitor.get("homeAway") not in ("home", "away"):
            return None
        names[team_id] = team.get("location") or team.get("displayName") or team_id
        conference = str(team.get("conferenceId"))
        if conference in FBS_CONFERENCES:
            fbs_ids.add(team_id)
            conferences[team_id] = conference
        sides[competitor["homeAway"]] = (team_id, score)
    if len(sides) != 2:
        return None
    return {
        "id": event.get("id"),
        "week": week if seasontype == 2 else 100 + week,
        "home": sides["home"][0], "away": sides["away"][0],
        "home_score": sides["home"][1], "away_score": sides["away"][1],
        "neutral": bool(competition.get("neutralSite")),
    }


def team_groups(games, fbs_ids, fcs_ids):
    teams = {g["home"] for g in games} | {g["away"] for g in games}
    return {t: "fbs" if t in fbs_ids else "fcs" if t in fcs_ids else "other" for t in teams}


# --- Ratings -----------------------------------------------------------------


def fit_ratings(games, fbs_ids, fcs_ids, cap=CAP, k=K):
    """Opponent-adjusted capped margin, Gauss-Seidel to convergence. Returns
    (ratings, hfa). FBS teams shrink toward 0, FCS teams toward the FCS mean
    and anyone else (Division II visitors) toward theirs. The group means and
    home-field advantage are re-estimated on every sweep."""
    group = team_groups(games, fbs_ids, fcs_ids)
    teams = set(group)
    schedule = {t: [] for t in teams}
    for g in games:
        margin = max(-cap, min(cap, g["home_score"] - g["away_score"])) if cap else \
            g["home_score"] - g["away_score"]
        site = 0 if g["neutral"] else 1
        schedule[g["home"]].append((g["away"], margin, site))
        schedule[g["away"]].append((g["home"], -margin, -site))
    ratings = {t: 0.0 for t in teams}
    prior = {"fbs": 0.0, "fcs": 0.0, "other": 0.0}
    hfa = 2.5
    for _ in range(500):
        moved = 0.0
        for t in teams:
            total = sum(m + ratings[o] - hfa * s for o, m, s in schedule[t])
            new = (total + k * prior[group[t]]) / (len(schedule[t]) + k)
            moved = max(moved, abs(new - ratings[t]))
            ratings[t] = new
        for name in ("fcs", "other"):
            members = [ratings[t] for t in teams if group[t] == name]
            if members:
                prior[name] = sum(members) / len(members)
        home_games = [g for g in games if not g["neutral"]]
        if home_games:
            residual = sum(
                max(-cap, min(cap, g["home_score"] - g["away_score"])) if cap else
                g["home_score"] - g["away_score"]
                for g in home_games) / len(home_games)
            gap = sum(ratings[g["home"]] - ratings[g["away"]] for g in home_games) / len(home_games)
            hfa = residual - gap
        if moved < 0.01:
            break
    fbs = [ratings[t] for t in teams if group[t] == "fbs"]
    shift = sum(fbs) / len(fbs) if fbs else 0.0
    return {t: r - shift for t, r in ratings.items()}, hfa


def win_probability(gap, sigma=SIGMA):
    return 0.5 * (1 + math.erf(gap / (sigma * math.sqrt(2))))


def percentile(values, q):
    ordered = sorted(values)
    position = q * (len(ordered) - 1)
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


# --- Résumé ------------------------------------------------------------------


def at_least(probabilities, wins):
    """P(at least `wins` successes) for independent games: Poisson-binomial
    by dynamic programming."""
    distribution = [1.0]
    for p in probabilities:
        nxt = [0.0] * (len(distribution) + 1)
        for count, mass in enumerate(distribution):
            nxt[count] += mass * (1 - p)
            nxt[count + 1] += mass * p
        distribution = nxt
    return sum(distribution[wins:])


def resume_table(games, fbs_ids, ratings, hfa, sigma=SIGMA):
    fbs_ratings = [ratings[t] for t in fbs_ids if t in ratings]
    bench = {name: percentile(fbs_ratings, q) for name, q in BENCHMARKS.items()}
    rows = []
    for team in fbs_ids:
        played = [g for g in games if team in (g["home"], g["away"])]
        if not played:
            continue
        wins = pf = pa = 0
        legs = []
        for g in played:
            home = g["home"] == team
            us, them = (g["home_score"], g["away_score"]) if home else (g["away_score"], g["home_score"])
            wins += us > them
            pf += us
            pa += them
            site = 0 if g["neutral"] else (1 if home else -1)
            legs.append((g["away"] if home else g["home"], site))
        row = {"team": team, "wins": wins, "losses": len(played) - wins, "pf": pf, "pa": pa,
               "strength": ratings[team], "games": legs}
        for name, level in bench.items():
            probs = [win_probability(level - ratings[o] + hfa * s, sigma) for o, s in legs]
            row[f"p_{name}"] = at_least(probs, wins)
        rows.append(row)
    rows.sort(key=lambda r: (r["p_high"], r["p_mid"], -(r["pf"] - r["pa"])))
    for index, row in enumerate(rows, 1):
        row["rank"] = index
        row["score"] = max(0.0, round(100 * (1 - row["p_high"]), 1))
    for index, row in enumerate(sorted(rows, key=lambda r: (r["p_mid"], r["p_high"])), 1):
        row["rank_mid"] = index
    return rows, bench


# --- Play-by-play ------------------------------------------------------------

PLAYS_VERSION = 1  # bump when compact() changes, so stale caches are ignored

RUNS = {"Rush", "Rushing Touchdown"}
PASSES = {"Pass Reception", "Pass Incompletion", "Passing Touchdown", "Sack", "Pass",
          "Pass Interception Return", "Interception", "Interception Return Touchdown"}
FUMBLES = {"Fumble", "Fumble Recovery (Own)", "Fumble Recovery (Opponent)",
           "Fumble Return Touchdown", "Safety"}
PUNTS = {"Punt", "Punt Return", "Blocked Punt", "Punt Return Touchdown", "Blocked Punt Touchdown"}
KICKOFFS = {"Kickoff", "Kickoff Return (Offense)", "Kickoff Return Touchdown"}
FIELD_GOALS = {"Field Goal Good", "Field Goal Missed", "Blocked Field Goal",
               "Blocked Field Goal Touchdown", "Missed Field Goal Return",
               "Missed Field Goal Return Touchdown"}
TURNOVERS = {"Pass Interception Return", "Interception", "Interception Return Touchdown",
             "Fumble Recovery (Opponent)", "Fumble Return Touchdown"}

# One cached play, as a list in this order.
FIELDS = ("kind", "team", "quarter", "down", "distance", "to_go", "yards", "margin",
          "scorer", "points", "turnover", "kneel", "pat", "next_team", "next_to_go")


def play_kind(type_text, text):
    if type_text in RUNS:
        return "run"
    if type_text in PASSES:
        return "pass"
    if type_text in FUMBLES:
        return "pass" if "pass" in text or "sack" in text else "run"
    if type_text in PUNTS:
        return "punt"
    if type_text in KICKOFFS:
        return "kickoff"
    if type_text in FIELD_GOALS:
        return "fg"
    return None


def as_int(value, fallback):
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def compact(summary):
    """A game summary reduced to the plays the ratings read, grouped by
    drive. A play's `team` is its start.team: the offense on a snap, the
    kicking team on a kick. ESPN's kick end spots are unreliable (a third
    of 2024's are flipped or wrong), so a kick records the receiving team's
    next snap instead. Scores on a play are after it, try included."""
    competition = ((summary.get("header") or {}).get("competitions") or [{}])[0]
    side = {c.get("homeAway"): str((c.get("team") or {}).get("id"))
            for c in competition.get("competitors") or []}
    drives, flat = [], []
    before = (0, 0)
    for drive in (summary.get("drives") or {}).get("previous") or []:
        plays = []
        for play in drive.get("plays") or []:
            type_text = (play.get("type") or {}).get("text") or ""
            text = (play.get("text") or "").lower()
            after = (max(before[0], as_int(play.get("homeScore"), before[0])),
                     max(before[1], as_int(play.get("awayScore"), before[1])))
            gained = (after[0] - before[0], after[1] - before[1])
            start = play.get("start") or {}
            entry = {
                "kind": play_kind(type_text, text),
                "team": (start.get("team") or {}).get("id"),
                "quarter": (play.get("period") or {}).get("number") or 0,
                "down": start.get("down"), "distance": start.get("distance"),
                "to_go": start.get("yardsToEndzone"), "yards": play.get("statYardage"),
                "margin": before[0] - before[1],
                "scorer": side.get("home") if gained[0] else side.get("away") if gained[1] else None,
                "points": max(gained), "turnover": type_text in TURNOVERS,
                "kneel": "kneel" in text or "spike" in text,
            }
            two_point = "two-point" in text or re.search(r"(pass|rush|run) attempt", text)
            if entry["points"] >= 6 and not two_point and re.search(r"\bkick\b|\bpat\b", text):
                entry["pat"] = entry["points"] >= 7
            if entry["kind"]:
                plays.append(entry)
                flat.append(entry)
            before = after
        drives.append({"team": str((drive.get("team") or {}).get("id")),
                       "result": drive.get("result") or "", "plays": plays})
    for index, entry in enumerate(flat):
        if entry["kind"] not in ("punt", "kickoff"):
            continue
        for later in flat[index + 1:]:
            if later["kind"] not in ("run", "pass"):
                break  # a re-kick after a penalty, or a score: no snap to read
            if later["down"] in (1, 2, 3, 4) and later["team"] and later["to_go"] is not None:
                entry["next_team"], entry["next_to_go"] = later["team"], later["to_go"]
                break
    return {"home": side.get("home"), "away": side.get("away"),
            "drives": [{**d, "plays": [[p.get(f) for f in FIELDS] for p in d["plays"]]}
                       for d in drives]}


def game_plays(event_id):
    path = os.path.join(CACHE, f"v{PLAYS_VERSION}", f"{event_id}.json")
    try:
        with open(path) as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        try:
            stored = compact(fetch(f"{SITE}/summary?event={event_id}"))
        except RuntimeError as error:
            print(f"warning: {error}", file=sys.stderr)
            return None
        if stored["drives"]:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as handle:
                json.dump(stored, handle, separators=(",", ":"))
    return {**stored, "drives": [{**d, "plays": [dict(zip(FIELDS, p)) for p in d["plays"]]}
                                 for d in stored["drives"]]}


def season_plays(games, fbs_ids):
    """Play-by-play for every game with an FBS team in it, by event id. A
    game ESPN has no drives for is left out and counted."""
    wanted = [g["id"] for g in games if g["home"] in fbs_ids or g["away"] in fbs_ids]
    with ThreadPoolExecutor(8) as pool:
        loaded = dict(zip(wanted, pool.map(game_plays, wanted)))
    plays = {event: game for event, game in loaded.items() if game and game["drives"]}
    if len(plays) < len(wanted):
        print(f"note: no play-by-play for {len(wanted) - len(plays)} of {len(wanted)} games; "
              "their résumé counts, their performance doesn't", file=sys.stderr)
    return plays


# --- Performance: offense and defense ----------------------------------------


def garbage(play):
    """Garbage time, Bill Connelly's line: a lead of more than 38 points in
    the second quarter, 28 in the third or 22 in the fourth. Never in the
    first quarter or overtime."""
    return abs(play["margin"]) > {2: 38, 3: 28, 4: 22}.get(play["quarter"], 999)


def is_snap(play, offense):
    """A scrimmage play the offense ran: not a kneel-down or spike."""
    return (play["kind"] in ("run", "pass") and play["team"] == offense
            and play["down"] in (1, 2, 3, 4) and not play["kneel"])


def successful(play, gained, offense):
    """Half the distance on first down, 70% on second, all of it on third
    and fourth. A touchdown always succeeds and a turnover never does."""
    if play["scorer"] == offense and play["points"] >= 6:
        return True
    if play["turnover"] or not play["distance"]:
        return False
    return gained >= {1: 0.5, 2: 0.7}.get(play["down"], 1.0) * play["distance"]


def drive_points(drive, offense):
    """What the offense scored on the drive: 7 for a touchdown, 3 for a
    field goal. A defensive or return score belongs to the other team."""
    total = 0
    for play in drive["plays"]:
        if play["scorer"] == offense and play["kind"] in ("run", "pass", "fg"):
            total += 7 if play["points"] >= 6 else 3 if play["points"] == 3 else 0
    return total


def meaningful(drive, snaps):
    """A possession that counts: it has a real snap, starts in regulation
    outside garbage time, and isn't cut off by the end of a half."""
    return (bool(snaps) and snaps[0]["quarter"] <= 4 and not garbage(snaps[0])
            and not drive["result"].upper().startswith("END"))


def offense_lines(game):
    """Each team's offense in one game, outside garbage time: snaps, yards,
    successes and explosive plays; meaningful possessions and their points;
    red-zone trips (a meaningful possession with a snap inside the 20) and
    their points."""
    lines = {game["home"]: collections.Counter(), game["away"]: collections.Counter()}
    for drive in game["drives"]:
        offense = drive["team"]
        if offense not in lines:
            continue
        line = lines[offense]
        snaps = [p for p in drive["plays"] if is_snap(p, offense)]
        for play in snaps:
            if garbage(play):
                continue
            gained = 0 if play["turnover"] else play["yards"] or 0
            line["plays"] += 1
            line["yards"] += gained
            line["success"] += successful(play, gained, offense)
            line["explosive"] += gained >= EXPLOSIVE[play["kind"]]
        if not meaningful(drive, snaps):
            continue
        points = drive_points(drive, offense)
        line["drives"] += 1
        line["points"] += points
        if any(p["to_go"] is not None and p["to_go"] <= 20 for p in snaps):
            line["trips"] += 1
            line["red_zone"] += points
    return lines


def fit_units(observations, groups, k_games):
    """One stat, opponent-adjusted: value = mean + offense[team] -
    defense[opponent] + home * site, weighted by snaps (or possessions, or
    trips). Gauss-Seidel to convergence. Each unit is pulled toward its
    group's average by k_games games' worth of weight, as in fit_ratings.
    Both sides are centered so the average FBS offense and defense are 0.
    A positive defense is a good one, meaning it allows less."""
    by_offense = collections.defaultdict(list)
    by_defense = collections.defaultdict(list)
    for observation in observations:
        by_offense[observation[0]].append(observation)
        by_defense[observation[1]].append(observation)
    total = sum(o[4] for o in observations)
    k = k_games * total / max(1, len(observations))
    mean = sum(o[3] * o[4] for o in observations) / total
    spread = math.sqrt(sum(o[4] * (o[3] - mean) ** 2 for o in observations) / total) or 1.0
    offense = {t: 0.0 for t in groups}
    defense = {t: 0.0 for t in groups}
    prior_o = {"fbs": 0.0, "fcs": 0.0, "other": 0.0}
    prior_d = dict(prior_o)
    home = 0.0
    sited = [o for o in observations if o[2]]
    for _ in range(300):
        moved = 0.0
        for t in groups:
            rows = by_offense.get(t, ())
            num = sum(w * (v - mean - home * s + defense[d]) for _, d, s, v, w in rows)
            new = (num + k * prior_o[groups[t]]) / (sum(o[4] for o in rows) + k)
            moved = max(moved, abs(new - offense[t]))
            offense[t] = new
        for t in groups:
            rows = by_defense.get(t, ())
            num = sum(w * (mean + offense[o] + home * s - v) for o, _, s, v, w in rows)
            new = (num + k * prior_d[groups[t]]) / (sum(o[4] for o in rows) + k)
            moved = max(moved, abs(new - defense[t]))
            defense[t] = new
        fbs = [t for t in groups if groups[t] == "fbs"]
        shift_o = sum(offense[t] for t in fbs) / len(fbs)
        shift_d = sum(defense[t] for t in fbs) / len(fbs)
        for t in groups:
            offense[t] -= shift_o
            defense[t] -= shift_d
        mean += shift_o - shift_d
        for name in ("fcs", "other"):
            members = [t for t in groups if groups[t] == name]
            if members:
                prior_o[name] = sum(offense[t] for t in members) / len(members)
                prior_d[name] = sum(defense[t] for t in members) / len(members)
        if sited:
            home = sum(w * s * (v - mean - offense[o] + defense[d]) for o, d, s, v, w in sited) / \
                sum(o[4] for o in sited)
        if moved < 1e-4 * spread:
            break
    return {"offense": offense, "defense": defense, "mean": mean, "home": home}


# --- Performance: special teams ----------------------------------------------


def smoothed(samples, bandwidth, low, high):
    """Gaussian-kernel mean of (x, value) samples on the integer grid
    low..high: a league baseline by yard line or kick distance."""
    sums, counts = collections.Counter(), collections.Counter()
    for x, value in samples:
        sums[round(x)] += value
        counts[round(x)] += 1
    grid = {}
    for x in range(low, high + 1):
        num = den = 0.0
        for at, count in counts.items():
            weight = math.exp(-0.5 * ((x - at) / bandwidth) ** 2)
            num += weight * sums[at]
            den += weight * count
        grid[x] = num / den if den else 0.0
    return lambda x: grid[max(low, min(high, round(x)))]


def special_teams(plays):
    """Each team-game's special-teams points against league baselines built
    from the same games.

    A kick ends with the receiving team's next snap, worth that spot's
    drive value: the average points a meaningful possession starting there
    scores. A return touchdown is worth 7 to the receivers, and a kick the
    kickers get back is worth minus their drive value. A punt or kickoff
    scores (expected receiving value from that kick spot) - (actual) for
    the kicking team, so it carries the coverage and the opponent's
    returner too. That is why a team's returns are shown, but are counted
    only through the other side's kicks. Field goals score 3 * (made -
    expected makes at that distance) and extra points (made - the league
    rate)."""
    drive_samples, field_goals, pats = [], [], []
    for game in plays.values():
        for drive in game["drives"]:
            snaps = [p for p in drive["plays"] if is_snap(p, drive["team"])]
            if snaps and snaps[0]["to_go"] and snaps[0]["quarter"] <= 4 and \
                    not drive["result"].upper().startswith("END"):
                drive_samples.append((snaps[0]["to_go"], drive_points(drive, drive["team"])))
            for play in drive["plays"]:
                if play["kind"] == "fg" and play["yards"]:
                    field_goals.append((play["yards"], play["scorer"] == play["team"]))
                if play["pat"] is not None:
                    pats.append(play["pat"])
    if not drive_samples:
        return {}
    drive_value = smoothed(drive_samples, 3, 1, 99)

    def received(play):
        kicker = play["team"]
        if play["points"] >= 6:
            return 7.0 if play["scorer"] != kicker else -7.0
        if play["next_to_go"] is None or not 1 <= play["next_to_go"] <= 99:
            return None
        value = drive_value(play["next_to_go"])
        return -value if play["next_team"] == kicker else value

    kicks = {"punt": [], "kickoff": []}
    for game in plays.values():
        for drive in game["drives"]:
            for play in drive["plays"]:
                if play["kind"] in kicks and play["to_go"]:
                    actual = received(play)
                    if actual is not None:
                        kicks[play["kind"]].append((play["to_go"], actual))
    expected = {kind: smoothed(samples, 3, 1, 99) for kind, samples in kicks.items() if samples}
    make = smoothed(field_goals, 2, 10, 70) if field_goals else (lambda x: 0.0)
    pat_rate = sum(pats) / len(pats) if pats else 0.0

    lines = {}
    for event, game in plays.items():
        teams = {game["home"]: collections.Counter(), game["away"]: collections.Counter()}
        for drive in game["drives"]:
            for play in drive["plays"]:
                kicker = play["team"]
                if kicker not in teams:
                    continue
                other = game["away"] if kicker == game["home"] else game["home"]
                if play["kind"] in expected and play["to_go"]:
                    actual = received(play)
                    if actual is not None:
                        value = expected[play["kind"]](play["to_go"]) - actual
                        teams[kicker][play["kind"]] += value
                        teams[other][f"{play['kind']}_return"] -= value
                elif play["kind"] == "fg" and play["yards"]:
                    teams[kicker]["field_goal"] += 3 * ((play["scorer"] == kicker) - make(play["yards"]))
                if play["pat"] is not None and play["scorer"] in teams:
                    teams[play["scorer"]]["extra_point"] += play["pat"] - pat_rate
        for line in teams.values():
            line["total"] = line["punt"] + line["kickoff"] + line["field_goal"] + line["extra_point"]
        lines[event] = teams
    return lines


# --- Performance: together ---------------------------------------------------


def performance(games, plays, fbs_ids, fcs_ids, hfa, weights=WEIGHTS, k=UNIT_K, st_k=ST_K):
    """Every team's offense, defense and special teams in points per game
    against an average FBS team, plus the opponent-adjusted stats behind
    them. Returns (by team, details)."""
    groups = team_groups(games, fbs_ids, fcs_ids)
    observations = {stat: [] for stat in STATS}
    for g in games:
        game = plays.get(g["id"])
        if not game:
            continue
        lines = offense_lines(game)
        site = 0 if g["neutral"] else 1
        for team, opponent, s in ((g["home"], g["away"], site), (g["away"], g["home"], -site)):
            line = lines.get(team)
            if not line:
                continue
            for stat, (numerator, denominator) in STATS.items():
                if line[denominator]:
                    observations[stat].append(
                        (team, opponent, s, line[numerator] / line[denominator], line[denominator]))
    units = {stat: fit_units(rows, groups, k) for stat, rows in observations.items() if rows}
    fbs = [t for t in groups if groups[t] == "fbs"]

    def index(side):
        out = {t: 0.0 for t in groups}
        for stat, fit in units.items():
            values = [fit[side][t] for t in fbs]
            spread = statistics.pstdev(values) or 1.0
            for t in groups:
                out[t] += weights.get(stat, 0.0) * fit[side][t] / spread
        return out

    offense_index, defense_index = index("offense"), index("defense")

    st_lines = special_teams({g["id"]: plays[g["id"]] for g in games if g["id"] in plays})
    st_games = [{"home": g["home"], "away": g["away"], "neutral": True,
                 "home_score": st_lines[g["id"]][g["home"]]["total"],
                 "away_score": st_lines[g["id"]][g["away"]]["total"]}
                for g in games if g["id"] in st_lines and
                {g["home"], g["away"]} <= set(st_lines[g["id"]])]
    special, _ = fit_ratings(st_games, fbs_ids, fcs_ids, cap=None, k=st_k) if st_games else ({}, 0)

    # Scale the two sums into points: least squares of each game's capped
    # margin, less home field and the special-teams gap, on the offense and
    # defense gaps.
    sxx = sxy = syy = sxz = syz = 0.0
    for g in games:
        h, a = g["home"], g["away"]
        target = max(-CAP, min(CAP, g["home_score"] - g["away_score"])) \
            - (0 if g["neutral"] else hfa) - (special.get(h, 0.0) - special.get(a, 0.0))
        x, y = offense_index[h] - offense_index[a], defense_index[h] - defense_index[a]
        sxx += x * x
        sxy += x * y
        syy += y * y
        sxz += x * target
        syz += y * target
    determinant = sxx * syy - sxy * sxy
    if determinant:
        scale_o = (sxz * syy - syz * sxy) / determinant
        scale_d = (syz * sxx - sxz * sxy) / determinant
    else:
        scale_o = scale_d = 0.0

    season_st = collections.defaultdict(collections.Counter)
    st_games_played = collections.Counter()
    for teams in st_lines.values():
        for team, line in teams.items():
            season_st[team].update(line)
            st_games_played[team] += 1

    out = {}
    for t in groups:
        played = st_games_played[t] or 1
        out[t] = {
            "offense": scale_o * offense_index[t],
            "defense": scale_d * defense_index[t],
            "special": special.get(t, 0.0),
            "stats": {stat: {"offense": fit["offense"][t], "defense": fit["defense"][t]}
                      for stat, fit in units.items()},
            "special_detail": {key: season_st[t][key] / played for key in
                               ("punt", "punt_return", "kickoff", "kickoff_return",
                                "field_goal", "extra_point")},
        }
        out[t]["performance"] = out[t]["offense"] + out[t]["defense"] + out[t]["special"]
    details = {"scale": (scale_o, scale_d),
               "means": {stat: fit["mean"] for stat, fit in units.items()},
               "home": {stat: fit["home"] for stat, fit in units.items()}}
    return out, details


# --- Overall and conferences -------------------------------------------------


def standardize(rows, key):
    values = [r[key] for r in rows]
    mean, spread = statistics.fmean(values), statistics.pstdev(values) or 1.0
    return {r["team"]: (r[key] - mean) / spread for r in rows}


def overall_table(rows, perf, conferences):
    """Résumé and performance on comparable scales, then two-thirds and
    one-third. The résumé is put in standard deviations first (the probit
    of 1 - P), so its tail separates as the performance gap does. Both are
    then standardized across FBS. Overall Score is the combined z read as a
    0-100 normal percentile."""
    normal = statistics.NormalDist()
    for row in rows:
        p = min(max(row["p_high"], 1e-6), 1 - 1e-6)
        row["resume_z"] = normal.inv_cdf(1 - p)
        unit = perf.get(row["team"]) or {}
        for key in ("offense", "defense", "special", "performance"):
            row[key] = unit.get(key, 0.0)
    resume_z = standardize(rows, "resume_z")
    performance_z = standardize(rows, "performance")
    for row in rows:
        row["combined"] = RESUME_WEIGHT * resume_z[row["team"]] + \
            (1 - RESUME_WEIGHT) * performance_z[row["team"]]
    combined_z = standardize(rows, "combined")
    for row in rows:
        row["overall_score"] = round(100 * normal.cdf(combined_z[row["team"]]), 1)
    for position, row in enumerate(sorted(rows, key=lambda r: (-r["combined"], r["rank"])), 1):
        row["overall_rank"] = position
    for position, row in enumerate(sorted(rows, key=lambda r: -r["performance"]), 1):
        row["performance_rank"] = position
    by_conference = collections.defaultdict(list)
    for row in rows:
        by_conference[conferences.get(row["team"])].append(row)
    for members in by_conference.values():
        for position, row in enumerate(sorted(members, key=lambda r: r["overall_rank"]), 1):
            row["conference_rank"] = position
    rows.sort(key=lambda r: r["overall_rank"])
    return rows


def conference_table(rows, conferences, names):
    """Conferences compared through their teams' ratings, ranked by average
    performance."""
    by_conference = collections.defaultdict(list)
    for row in rows:
        if row["team"] in conferences:
            by_conference[conferences[row["team"]]].append(row)
    table = []
    for conference, members in by_conference.items():
        best = min(members, key=lambda r: r["overall_rank"])
        table.append({
            "conference": FBS_CONFERENCES.get(conference, conference), "teams": len(members),
            "performance": statistics.fmean(r["performance"] for r in members),
            "offense": statistics.fmean(r["offense"] for r in members),
            "defense": statistics.fmean(r["defense"] for r in members),
            "special": statistics.fmean(r["special"] for r in members),
            "strength": statistics.fmean(r["strength"] for r in members),
            "top_25": sum(r["overall_rank"] <= 25 for r in members),
            "best": names.get(best["team"], best["team"]), "best_rank": best["overall_rank"],
        })
    table.sort(key=lambda c: -c["performance"])
    for position, entry in enumerate(table, 1):
        entry["rank"] = position
    return table


def opponent_strength(ratings, perf, mode=None):
    """The strength the résumé's win probabilities read, with its sigma:
    the margin rating alone, or its average with performance."""
    if (mode or RESUME_STRENGTH) == "blend":
        return {t: (r + perf[t]["performance"]) / 2 if t in perf else r
                for t, r in ratings.items()}, BLEND_SIGMA
    return ratings, SIGMA


def rank_season(games, fbs_ids, names, conferences, plays, mode=None):
    """Everything for one slate of games. Returns (rows, benchmarks, the
    résumé's opponent strength, its sigma, hfa, performance, performance
    details, the conference table)."""
    fcs_ids = {t for g in games for t in (g["home"], g["away"])} - fbs_ids
    ratings, hfa = fit_ratings(games, fbs_ids, fcs_ids)
    perf, details = performance(games, plays, fbs_ids, fcs_ids, hfa)
    strength, sigma = opponent_strength(ratings, perf, mode)
    rows, bench = resume_table(games, fbs_ids, strength, hfa, sigma)
    rows = overall_table(rows, perf, conferences)
    return (rows, bench, strength, sigma, hfa, perf, details,
            conference_table(rows, conferences, names))


# --- Comparisons -------------------------------------------------------------


def espn_power_index(season):
    """ESPN's Strength of Record rank (`accomplishmentrank`) and FPI rank,
    by team id."""
    data = fetch(f"{FPI}?region=us&lang=en&season={season}&group=80&limit=200")
    wanted = {"resume": "accomplishmentrank", "fpi": "fpirank"}
    columns = {}
    for category in data.get("categories", []):
        if category.get("name") in wanted and wanted[category["name"]] in category.get("names", []):
            columns[category["name"]] = category["names"].index(wanted[category["name"]])
    ranks = {"resume": {}, "fpi": {}}
    for entry in data.get("teams", []):
        for category in entry.get("categories", []):
            name = category.get("name")
            if name in columns:
                values = category.get("values") or []
                if columns[name] < len(values) and values[columns[name]] is not None:
                    ranks[name][entry["team"]["id"]] = int(values[columns[name]])
    return ranks["resume"], ranks["fpi"]


def committee_ranking(season, week=16):
    data = fetch(f"{CORE}/seasons/{season}/types/2/weeks/{week}/rankings/21")
    ranks = {}
    for entry in data.get("ranks", []):
        match = re.search(r"teams/(\d+)", (entry.get("team") or {}).get("$ref", ""))
        if match:
            ranks[match.group(1)] = entry.get("current")
    return ranks


def spearman(pairs):
    """Rank correlation of (a, b) pairs, re-ranked within the shared set."""
    if len(pairs) < 3:
        return float("nan")

    def rerank(values):
        order = sorted(range(len(values)), key=lambda i: values[i])
        out = [0] * len(values)
        for position, i in enumerate(order):
            out[i] = position
        return out
    a = rerank([p[0] for p in pairs])
    b = rerank([p[1] for p in pairs])
    n = len(pairs)
    return 1 - 6 * sum((x - y) ** 2 for x, y in zip(a, b)) / (n * (n * n - 1))


# --- Backtest ----------------------------------------------------------------


def predictions(games, fbs_ids, week, rating_fn, sigma):
    """(correct, brier, count) for next week's games with an FBS team."""
    right = total = 0
    brier = 0.0
    for g in games:
        if g["week"] != week + 1 or g["home_score"] == g["away_score"]:
            continue
        if g["home"] not in fbs_ids and g["away"] not in fbs_ids:
            continue
        gap = rating_fn(g)
        if gap is None:
            continue
        p = win_probability(gap, sigma)
        home_won = g["home_score"] > g["away_score"]
        right += (p > 0.5) == home_won
        brier += (p - home_won) ** 2
        total += 1
    return right, brier, total


def score_weeks(games, fbs_ids, fits, gap_fn, sigma):
    right = total = 0
    brier = 0.0
    for week, fit in fits.items():
        r, b, t = predictions(games, fbs_ids, week, lambda g: gap_fn(fit, g), sigma)
        right += r
        brier += b
        total += t
    return brier / total, right / total, total


def margin_gap(fit, g):
    ratings, hfa = fit[0], fit[1]
    if g["home"] not in ratings or g["away"] not in ratings:
        return None
    return ratings[g["home"]] - ratings[g["away"]] + (0 if g["neutral"] else hfa)


def performance_gap(fit, g):
    perf, hfa = fit[2], fit[1]
    if g["home"] not in perf or g["away"] not in perf:
        return None
    return perf[g["home"]]["performance"] - perf[g["away"]]["performance"] + \
        (0 if g["neutral"] else hfa)


def blend_gap(fit, g):
    a, b = margin_gap(fit, g), performance_gap(fit, g)
    return None if a is None or b is None else (a + b) / 2


def backtest(season):
    print(f"Fetching {season} regular season and postseason…", file=sys.stderr)
    games, fbs_ids, names, conferences = season_games(season)
    post, post_fbs, post_names, post_conferences = season_games(season, seasontype=3,
                                                                weeks=range(1, 2))
    fbs_ids |= post_fbs
    names.update(post_names)
    conferences.update(post_conferences)
    fcs_ids = {t for g in games for t in (g["home"], g["away"])} - fbs_ids
    plays = season_plays(games + post, fbs_ids)
    last_week = max(g["week"] for g in games)
    weeks = range(4, last_week)
    header = f"{'acc':>6} {'brier':>7} {'n':>5}"

    print(f"\nMargin rating, weeks 4-{last_week - 1} -> next week, games with an FBS team")
    print(f"{'cap':>4} {'k':>4} {'sigma':>6} {header}")
    results = []
    for cap in (21, 28, 35, None):
        for k in (0.5, 1.0, 2.0, 3.0):
            fits = {}
            for week in weeks:
                seen = [g for g in games if g["week"] <= week]
                fits[week] = fit_ratings(seen, fbs_ids, fcs_ids, cap, k)
            for sigma in (12.0, 14.0, 16.0, 18.0, 20.0):
                brier, accuracy, total = score_weeks(games, fbs_ids, fits, margin_gap, sigma)
                results.append((brier, accuracy, cap, k, sigma, total))
    results.sort()
    for brier, accuracy, cap, k, sigma, total in results[:5]:
        print(f"{str(cap):>4} {k:>4} {sigma:>6} {accuracy:>6.1%} {brier:>7.4f} {total:>5}")
    current = next(r for r in results if r[2] == CAP and r[3] == K and r[4] == SIGMA)
    print(f"chosen (cap {CAP}, k {K}, sigma {SIGMA}): acc {current[1]:.1%}, brier {current[0]:.4f}")

    print("\nPerformance rating (play-by-play), same weeks")
    print(f"{'unit k':>6} {'st k':>5} {'sigma':>6} {header}  blend with margin")
    perf_results = []
    fits_by_k = {}
    for unit_k in (1.0, 2.0, 4.0):
        for st_k in (2.0, 6.0):
            fits = {}
            for week in weeks:
                seen = [g for g in games if g["week"] <= week]
                ratings, hfa = fit_ratings(seen, fbs_ids, fcs_ids)
                perf, _ = performance(seen, plays, fbs_ids, fcs_ids, hfa, k=unit_k, st_k=st_k)
                fits[week] = (ratings, hfa, perf)
            fits_by_k[(unit_k, st_k)] = fits
            for sigma in (12.0, 14.0, 16.0, 18.0):
                scored = score_weeks(games, fbs_ids, fits, performance_gap, sigma)
                blended = score_weeks(games, fbs_ids, fits, blend_gap, sigma)
                perf_results.append((scored, blended, unit_k, st_k, sigma))
    perf_results.sort(key=lambda r: r[0][0])
    for (brier, accuracy, total), (b_brier, b_acc, _), unit_k, st_k, sigma in perf_results[:6]:
        print(f"{unit_k:>6} {st_k:>5} {sigma:>6} {accuracy:>6.1%} {brier:>7.4f} {total:>5}"
              f"  {b_acc:.1%} {b_brier:.4f}")
    chosen = next(r for r in perf_results
                  if r[2] == UNIT_K and r[3] == ST_K and r[4] == PERFORMANCE_SIGMA)
    print(f"chosen (unit k {UNIT_K}, st k {ST_K}, sigma {PERFORMANCE_SIGMA}): "
          f"acc {chosen[0][1]:.1%}, brier {chosen[0][0]:.4f}; "
          f"blend acc {chosen[1][1]:.1%}, brier {chosen[1][0]:.4f}")

    print("\nPerformance weightings at the chosen constants")
    for label, weights in (("chosen", WEIGHTS),
                           ("equal", {s: 0.2 for s in STATS}),
                           ("points per possession only", {"points": 1.0}),
                           ("per-play stats only", {"ypp": 0.4, "success": 0.4, "explosive": 0.2})):
        fits = {}
        for week in weeks:
            seen = [g for g in games if g["week"] <= week]
            ratings, hfa = fit_ratings(seen, fbs_ids, fcs_ids)
            perf, _ = performance(seen, plays, fbs_ids, fcs_ids, hfa, weights=weights)
            fits[week] = (ratings, hfa, perf)
        brier, accuracy, _ = score_weeks(games, fbs_ids, fits, performance_gap, PERFORMANCE_SIGMA)
        print(f"  {label:<28} acc {accuracy:.1%}  brier {brier:.4f}")

    rows, *_ = rank_season(games, fbs_ids, names, conferences, plays)
    committee = committee_ranking(season)
    print(f"\nEnd of regular season vs the committee's final top 25 ({len(committee)} teams)")
    for label, key in (("résumé", "rank"), ("overall", "overall_rank"),
                       ("performance", "performance_rank")):
        pairs = [(r[key], committee[r["team"]]) for r in rows if r["team"] in committee]
        top = {r["team"] for r in rows if r[key] <= 25}
        print(f"  {label:<12} Spearman {spearman(pairs):.3f}, {len(top & set(committee))} of 25 shared")
    print_disagreements(rows, committee, names, "CFP", "overall_rank")
    top = {r["team"] for r in rows[:25]}
    print(f"  résumé top 25 changes between the high and mid benchmarks: "
          f"{len({r['team'] for r in rows if r['rank'] <= 25} - {r['team'] for r in rows if r['rank_mid'] <= 25})}")
    print(f"  overall top 25 vs résumé top 25: {len(top - {r['team'] for r in rows if r['rank'] <= 25})} differ")

    rows, *_ = rank_season(games + post, fbs_ids, names, conferences, plays)
    sor, fpi = espn_power_index(season)
    print("\nWith the postseason vs ESPN's final ratings")
    for label, key, other in (("résumé vs SOR", "rank", sor),
                              ("performance vs FPI", "performance_rank", fpi),
                              ("overall vs SOR", "overall_rank", sor)):
        pairs = [(r[key], other[r["team"]]) for r in rows if r["team"] in other]
        top_pairs = [(r[key], other[r["team"]]) for r in rows
                     if r["team"] in other and other[r["team"]] <= 25]
        print(f"  {label:<20} Spearman {spearman(pairs):.3f} over {len(pairs)} teams, "
              f"{spearman(top_pairs):.3f} over its top 25")


def print_disagreements(rows, other, names, label, key="rank"):
    gaps = sorted(((abs(r[key] - other[r["team"]]), r) for r in rows if r["team"] in other),
                  key=lambda item: -item[0])
    for _, row in gaps[:6]:
        print(f"    {names.get(row['team'], row['team']):<20} {row['wins']}-{row['losses']}"
              f"  ours {row[key]:>3}  {label} {other[row['team']]:>3}")


# --- Notion ------------------------------------------------------------------


def notion(method, path, body=None):
    token = os.environ.get("NOTION_TOKEN")
    if not token:
        sys.exit("NOTION_TOKEN is not set: create an internal integration, share the "
                 "College Football Teams 2026 database with it, and export its token.")
    request = urllib.request.Request(
        f"https://api.notion.com/v1/{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token}", "Notion-Version": "2025-09-03",
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def notion_properties(row):
    """The columns one team's row gets, by Notion property name. Adding 0.0
    turns a rounded -0.0 into 0.0."""
    return {
        "Overall Rank": row["overall_rank"],
        "Overall Score": row["overall_score"],
        "Résumé Rank": row["rank"],
        "Résumé Score": row["score"],
        "Résumé Rank (Avg Team)": row["rank_mid"],
        "Strength": round(row["strength"], 1) + 0.0,
        "Performance Rank": row["performance_rank"],
        "Performance": round(row["performance"], 1) + 0.0,
        "Offense": round(row["offense"], 1) + 0.0,
        "Defense": round(row["defense"], 1) + 0.0,
        "Special Teams": round(row["special"], 1) + 0.0,
        "Conf Rank": row["conference_rank"],
    }


def write_notion(rows, names):
    pages = []
    cursor = None
    while True:
        body = {"page_size": 100, **({"start_cursor": cursor} if cursor else {})}
        data = notion("POST", f"data_sources/{NOTION_DATA_SOURCE}/query", body)
        pages += data.get("results", [])
        if not data.get("has_more"):
            break
        cursor = data.get("next_cursor")
    by_id, by_title = {}, {}
    for page in pages:
        props = page.get("properties", {})
        url = (props.get("ESPN") or {}).get("url") or ""
        match = re.search(r"/id/(\d+)", url)
        if match:
            by_id[match.group(1)] = page["id"]
        title = "".join(t.get("plain_text", "") for t in (props.get("Team") or {}).get("title", []))
        by_title[title.lower()] = page["id"]
    written, missing = 0, []
    for row in rows:
        page = by_id.get(row["team"]) or by_title.get(names.get(row["team"], "").lower())
        if not page:
            missing.append(names.get(row["team"], row["team"]))
            continue
        notion("PATCH", f"pages/{page}", {"properties": {
            name: {"number": value} for name, value in notion_properties(row).items()}})
        written += 1
        time.sleep(0.35)  # Notion's API allows about three requests a second
    print(f"Notion: wrote {written} rows", file=sys.stderr)
    if missing:
        print(f"Notion: no row for {len(missing)} teams: {', '.join(sorted(missing))}", file=sys.stderr)


def write_notion_conferences(table, season, week):
    """Replace the conference page's body with this week's table."""
    def cell(value):
        return [{"type": "text", "text": {"content": str(value)}}]
    header = ["#", "Conference", "Teams", "Performance", "Offense", "Defense",
              "Special teams", "Strength", "Overall top 25", "Best team"]
    rows = [header] + [[c["rank"], c["conference"], c["teams"], f"{c['performance']:+.1f}",
                        f"{c['offense']:+.1f}", f"{c['defense']:+.1f}", f"{c['special']:+.1f}",
                        f"{c['strength']:+.1f}", c["top_25"], f"{c['best']} ({c['best_rank']})"]
                       for c in table]
    for block in notion("GET", f"blocks/{NOTION_CONFERENCE_PAGE}/children?page_size=100")["results"]:
        notion("DELETE", f"blocks/{block['id']}")
    notion("PATCH", f"blocks/{NOTION_CONFERENCE_PAGE}/children", {"children": [
        {"object": "block", "type": "paragraph", "paragraph": {"rich_text": cell(
            conference_markdown(table, season, week).split("\n")[0])}},
        {"object": "block", "type": "table", "table": {
            "table_width": len(header), "has_column_header": True,
            "children": [{"object": "block", "type": "table_row",
                          "table_row": {"cells": [cell(v) for v in row]}} for row in rows]}},
    ]})
    print("Notion: wrote the conference table", file=sys.stderr)


def conference_markdown(table, season, week):
    lines = [f"Conferences ranked by their teams' average performance, {season} through "
             f"week {week}. Points per game against an average FBS team on a neutral field.",
             "",
             "| # | Conference | Teams | Performance | Offense | Defense | Special teams "
             "| Strength | Overall top 25 | Best team |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for c in table:
        lines.append(f"| {c['rank']} | {c['conference']} | {c['teams']} | {c['performance']:+.1f} "
                     f"| {c['offense']:+.1f} | {c['defense']:+.1f} | {c['special']:+.1f} "
                     f"| {c['strength']:+.1f} | {c['top_25']} | {c['best']} ({c['best_rank']}) |")
    return "\n".join(lines)


# --- Main --------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--season", type=int, default=datetime.date.today().year
                        if datetime.date.today().month >= 7 else datetime.date.today().year - 1)
    parser.add_argument("--through-week", type=int, default=16)
    parser.add_argument("--postseason", action="store_true", help="include bowls and the CFP")
    parser.add_argument("--json", metavar="PATH")
    parser.add_argument("--notion", action="store_true")
    parser.add_argument("--force", action="store_true", help="publish to Notion before week 4")
    parser.add_argument("--backtest", action="store_true")
    parser.add_argument("--show", metavar="TEAM", help="print one team's games and ratings")
    args = parser.parse_args()

    if args.backtest:
        backtest(args.season)
        return

    games, fbs_ids, names, conferences = season_games(args.season,
                                                      weeks=range(1, args.through_week + 1))
    if args.postseason:
        post, post_fbs, post_names, post_conferences = season_games(
            args.season, seasontype=3, weeks=range(1, 2))
        games += post
        fbs_ids |= post_fbs
        names.update(post_names)
        conferences.update(post_conferences)
    if not games:
        sys.exit("No completed games yet.")
    last_week = max(g["week"] for g in games if g["week"] < 100)
    if args.notion and last_week < PUBLISH_FROM_WEEK and not args.force:
        sys.exit(f"Week {last_week}: the ranking publishes from week {PUBLISH_FROM_WEEK} "
                 "(--force to publish anyway).")
    plays = season_plays(games, fbs_ids)
    rows, bench, ratings, sigma, hfa, perf, details, conference_rows = rank_season(
        games, fbs_ids, names, conferences, plays)
    try:
        sor, fpi = espn_power_index(args.season)
    except RuntimeError:
        sor, fpi = {}, {}

    print(f"{args.season} through week {last_week}: {len(games)} games ({len(plays)} with "
          f"play-by-play), {len(rows)} FBS teams, home field {hfa:.1f}, benchmarks high "
          f"{bench['high']:+.1f} / mid {bench['mid']:+.1f} / low {bench['low']:+.1f}")
    if last_week < PUBLISH_FROM_WEEK:
        print(f"Early season: the proposal publishes from week {PUBLISH_FROM_WEEK}; "
              "these are provisional.")
    print(f"{'#':>3}  {'Team':<20} {'W-L':>5} {'Score':>6} {'Rés#':>5} {'Rés':>5} "
          f"{'Perf#':>5} {'Perf':>6} {'Off':>6} {'Def':>6} {'ST':>5} {'SOR':>4} {'FPI':>4}")
    for row in rows:
        print(f"{row['overall_rank']:>3}  {names.get(row['team'], row['team'])[:20]:<20} "
              f"{row['wins']:>2}-{row['losses']:<2} {row['overall_score']:>6.1f} {row['rank']:>5} "
              f"{row['score']:>5.1f} {row['performance_rank']:>5} {row['performance']:>+6.1f} "
              f"{row['offense']:>+6.1f} {row['defense']:>+6.1f} {row['special']:>+5.1f} "
              f"{sor.get(row['team'], ''):>4} {fpi.get(row['team'], ''):>4}")
    for label, key, other in (("résumé vs ESPN SOR", "rank", sor),
                              ("performance vs ESPN FPI", "performance_rank", fpi)):
        pairs = [(r[key], other[r["team"]]) for r in rows if r["team"] in other]
        if pairs:
            print(f"Spearman, {label}: {spearman(pairs):.3f} over {len(pairs)} teams")
    print()
    print(conference_markdown(conference_rows, args.season, last_week))

    if args.show:
        row = next((r for r in rows if names.get(r["team"], "").lower() == args.show.lower()), None)
        if row:
            unit = perf[row["team"]]
            print(f"\n{names[row['team']]} {row['wins']}-{row['losses']}, high benchmark {bench['high']:+.1f}")
            for opponent, site in row["games"]:
                p = win_probability(bench["high"] - ratings[opponent] + hfa * site, sigma)
                where = {1: "vs", -1: "at", 0: "n."}[site]
                print(f"  {where} {names.get(opponent, opponent):<22} {ratings[opponent]:+6.1f}  p(win) {p:.3f}")
            print(f"  P(benchmark wins >= {row['wins']}) = {row['p_high']:.4f}")
            print("  Opponent-adjusted, against the FBS average (defense: positive allows less)")
            for stat, sides in unit["stats"].items():
                print(f"    {stat:<10} offense {sides['offense']:+.3f}  defense {sides['defense']:+.3f}"
                      f"   (average {details['means'][stat]:.3f})")
            print("  Special teams per game: " + ", ".join(
                f"{key} {value:+.2f}" for key, value in unit["special_detail"].items()))

    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"season": args.season, "through_week": last_week, "hfa": hfa,
                       "benchmarks": bench, "scale": details["scale"],
                       "conferences": conference_rows,
                       "rows": [{**{k: v for k, v in r.items() if k != "games"},
                                 "name": names.get(r["team"]),
                                 "conference": FBS_CONFERENCES.get(conferences.get(r["team"])),
                                 "notion": notion_properties(r),
                                 "stats": perf[r["team"]]["stats"],
                                 "special_detail": perf[r["team"]]["special_detail"]}
                                for r in rows]}, handle, indent=1)
    if args.notion:
        write_notion(rows, names)
        write_notion_conferences(conference_rows, args.season, last_week)


if __name__ == "__main__":
    main()
