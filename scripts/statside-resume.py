#!/usr/bin/env python3
"""The StatSide résumé: FBS ranked by how hard each team's record would be.

The question it answers, from the ranking proposal Andy adopted on
2026-10-27 (résumé half only): how likely is a fixed benchmark team -- one
as strong as the 90th-percentile FBS team -- to match or beat this team's
record against this team's exact schedule, with home, away and neutral
counted? The less likely, the better the résumé. Every team is measured
against the same benchmark, and the whole probability is used (a
Poisson-binomial over the games), not wins minus expected wins: two
schedules with the same expected wins can make 10-2 very differently hard.

The opponents' strength behind those probabilities is a rating, not a rank
position -- the gap between No. 1 and No. 2 is not the gap between No. 20
and No. 21. It is an opponent-adjusted scoring margin, fit to every
Division I game of the season so far:

    capped margin(home) = r_home - r_away + HFA      (HFA 0 at neutral sites)

solved by Gauss-Seidel until no rating moves more than 0.01, with each team
pulled toward its group's average by K phantom games (FBS toward 0, FCS and
everyone else toward their own group mean), so a team with little evidence
stays near average. Margins are capped at CAP points, which blunts blowouts
and garbage time. The fit is redone from scratch every run, so early
opponents get re-rated as their seasons play out. The rating is an input
here, published only so the résumé can be checked.

Usage:
  scripts/statside-resume.py                       # this season, table
  scripts/statside-resume.py --season 2025 --through-week 10
  scripts/statside-resume.py --json out.json
  scripts/statside-resume.py --notion              # write Notion columns
  scripts/statside-resume.py --season 2025 --backtest

--notion needs NOTION_TOKEN (an internal integration the College Football
Teams 2026 database is shared with). Rows are matched by the ESPN team id in
the database's ESPN url, then by title; a team that matches neither is
reported, never guessed.

--backtest refits each week of a past season on only the games played by
then, predicts the next week's winners, grids the constants below by Brier
score, and compares the end-of-season résumé with ESPN's Strength of Record
and the committee's final ranking.
"""

import argparse
import datetime
import json
import math
import os
import re
import sys
import time
import urllib.request

SITE = "https://site.api.espn.com/apis/site/v2/sports/football/college-football"
CORE = "https://sports.core.api.espn.com/v2/sports/football/leagues/college-football"
FPI = "https://site.web.api.espn.com/apis/fitt/v3/sports/football/college-football/powerindex"
NOTION_DATA_SOURCE = "0613b72e-4ad6-4ed4-9dce-1d90a675ca0d"
NOTION_DATABASE = "bb7db8c801a14cd199b7e7c6b164c4a9"

# ESPN conference ids that are FBS: American, ACC, Big 12, Big Ten, CUSA,
# FBS Independents, MAC, Mountain West, Pac-12, SEC, Sun Belt.
FBS_CONFERENCES = {"151", "1", "4", "5", "12", "18", "15", "17", "9", "8", "37"}
LIMIT = 300

# The fit's constants, tuned by --backtest on 2024 and 2025 (see
# docs/statside-resume.md). SIGMA is the spread of a game's margin
# around the rating gap: it turns a gap into a win probability. Uncapped
# margins and lighter shrinkage predicted a hair better (Brier 0.179 vs 0.182
# in 2025, 0.189 vs 0.191 in 2024) but won fewer games straight up; the cap
# keeps garbage time out and K = 1 keeps week-four ratings from swinging.
CAP = 35
K = 1.0
SIGMA = 16.0

BENCHMARKS = {"high": 0.90, "mid": 0.50, "low": 0.25}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "StatSide résumé script"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except Exception as error:  # noqa: BLE001 -- retried, then reported
            if attempt == 2:
                raise RuntimeError(f"{url}: {error}") from error
            time.sleep(1 + attempt)


# --- Games -------------------------------------------------------------------


def season_games(season, seasontype=2, weeks=range(1, 17)):
    """Every completed Division I game: FBS (groups=80, which brings their
    FCS opponents along) and FCS-vs-FCS (groups=81), deduped by event id."""
    games = {}
    fbs_ids = set()
    names = {}
    for week in weeks:
        for group in ("80", "81"):
            url = (f"{SITE}/scoreboard?groups={group}&limit={LIMIT}&week={week}"
                   f"&seasontype={seasontype}&dates={season}")
            events = fetch(url).get("events") or []
            if len(events) >= LIMIT:
                print(f"warning: week {week} group {group} came back at the {LIMIT} limit; "
                      "games may be missing", file=sys.stderr)
            for event in events:
                game = parse_game(event, week, seasontype, fbs_ids, names)
                if game:
                    games[game["id"]] = game
    return list(games.values()), fbs_ids, names


def parse_game(event, week, seasontype, fbs_ids, names):
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
        if str(team.get("conferenceId")) in FBS_CONFERENCES:
            fbs_ids.add(team_id)
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


# --- Ratings -----------------------------------------------------------------


def fit_ratings(games, fbs_ids, fcs_ids, cap=CAP, k=K):
    """Opponent-adjusted capped margin, Gauss-Seidel to convergence. Returns
    (ratings, hfa). FBS teams shrink toward 0, FCS teams toward the FCS mean
    and anyone else (Division II visitors) toward theirs; the group means and
    home-field advantage are re-estimated each sweep."""
    teams = {g["home"] for g in games} | {g["away"] for g in games}
    group = {t: "fbs" if t in fbs_ids else "fcs" if t in fcs_ids else "other" for t in teams}
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


# --- Comparisons -------------------------------------------------------------


def espn_sor(season):
    """ESPN's Strength of Record rank (`accomplishmentrank`), by team id."""
    data = fetch(f"{FPI}?region=us&lang=en&season={season}&group=80&limit=200")
    names = next((c["names"] for c in data.get("categories", []) if c["name"] == "resume"), [])
    if "accomplishmentrank" not in names:
        return {}
    index = names.index("accomplishmentrank")
    ranks = {}
    for entry in data.get("teams", []):
        for category in entry.get("categories", []):
            if category.get("name") == "resume":
                value = (category.get("values") or [None] * (index + 1))[index]
                if value is not None:
                    ranks[entry["team"]["id"]] = int(value)
    return ranks


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


def backtest(season):
    print(f"Fetching {season} regular season and postseason…", file=sys.stderr)
    games, fbs_ids, names = season_games(season)
    post, post_fbs, post_names = season_games(season, seasontype=3, weeks=range(1, 2))
    fbs_ids |= post_fbs
    names.update(post_names)
    fcs_ids = {t for g in games for t in (g["home"], g["away"])} - fbs_ids
    last_week = max(g["week"] for g in games)

    print(f"\nWeekly prediction, weeks 4-{last_week - 1} -> next week, games with an FBS team")
    print(f"{'cap':>4} {'k':>4} {'sigma':>6} {'acc':>6} {'brier':>7} {'n':>5}")
    results = []
    for cap in (21, 28, 35, None):
        for k in (0.5, 1.0, 2.0, 3.0):
            fits = {}
            for week in range(4, last_week):
                seen = [g for g in games if g["week"] <= week]
                fits[week] = fit_ratings(seen, fbs_ids, fcs_ids, cap, k)
            for sigma in (12.0, 14.0, 16.0, 18.0, 20.0):
                right = total = 0
                brier = 0.0
                for week, (ratings, hfa) in fits.items():
                    for g in games:
                        if g["week"] != week + 1 or g["home_score"] == g["away_score"]:
                            continue
                        if g["home"] not in fbs_ids and g["away"] not in fbs_ids:
                            continue
                        if g["home"] not in ratings or g["away"] not in ratings:
                            continue
                        gap = ratings[g["home"]] - ratings[g["away"]] + (0 if g["neutral"] else hfa)
                        p = win_probability(gap, sigma)
                        home_won = g["home_score"] > g["away_score"]
                        right += (p > 0.5) == home_won
                        brier += (p - home_won) ** 2
                        total += 1
                results.append((brier / total, right / total, cap, k, sigma, total))
    results.sort()
    for brier, accuracy, cap, k, sigma, total in results[:8]:
        print(f"{str(cap):>4} {k:>4} {sigma:>6} {accuracy:>6.1%} {brier:>7.4f} {total:>5}")
    current = next(r for r in results if r[2] == CAP and r[3] == K and r[4] == SIGMA)
    print(f"current constants (cap {CAP}, k {K}, sigma {SIGMA}): "
          f"acc {current[1]:.1%}, brier {current[0]:.4f}")

    ratings, hfa = fit_ratings(games, fbs_ids, fcs_ids)
    rows, _ = resume_table(games, fbs_ids, ratings, hfa)
    committee = committee_ranking(season)
    pairs = [(r["rank"], committee[r["team"]]) for r in rows if r["team"] in committee]
    print(f"\nEnd of regular season vs the committee's final top 25: "
          f"Spearman {spearman(pairs):.3f} over {len(pairs)} teams")
    top = {r["team"] for r in rows[:25]}
    print(f"  overlap with the committee's 25: {len(top & set(committee))}")
    print_disagreements(rows, committee, names, "CFP")
    shift_count = len(top - {r["team"] for r in rows if r["rank_mid"] <= 25})
    print(f"  top 25 changes between the high and mid benchmarks: {shift_count}")

    ratings, hfa = fit_ratings(games + post, fbs_ids, fcs_ids)
    rows, _ = resume_table(games + post, fbs_ids, ratings, hfa)
    sor = espn_sor(season)
    pairs = [(r["rank"], sor[r["team"]]) for r in rows if r["team"] in sor]
    top_pairs = [(r["rank"], sor[r["team"]]) for r in rows if r["team"] in sor and sor[r["team"]] <= 25]
    print(f"\nWith the postseason vs ESPN's final Strength of Record: Spearman "
          f"{spearman(pairs):.3f} over {len(pairs)} teams, {spearman(top_pairs):.3f} over SOR's top 25")
    print_disagreements(rows, {t: s for t, s in sor.items() if s <= 25}, names, "SOR")


def print_disagreements(rows, other, names, label):
    gaps = sorted(((abs(r["rank"] - other[r["team"]]), r) for r in rows if r["team"] in other),
                  key=lambda item: -item[0])
    for gap, row in gaps[:6]:
        print(f"    {names.get(row['team'], row['team']):<20} {row['wins']}-{row['losses']}"
              f"  résumé {row['rank']:>3}  {label} {other[row['team']]:>3}")


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
            "Résumé Rank": {"number": row["rank"]},
            "Résumé Score": {"number": row["score"]},
            "Résumé Rank (Avg Team)": {"number": row["rank_mid"]},
            "Strength": {"number": round(row["strength"], 1)},
        }})
        written += 1
        time.sleep(0.35)  # Notion's API allows about three requests a second
    print(f"Notion: wrote {written} rows", file=sys.stderr)
    if missing:
        print(f"Notion: no row for {len(missing)} teams: {', '.join(sorted(missing))}", file=sys.stderr)


# --- Main --------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--season", type=int, default=datetime.date.today().year
                        if datetime.date.today().month >= 7 else datetime.date.today().year - 1)
    parser.add_argument("--through-week", type=int, default=16)
    parser.add_argument("--postseason", action="store_true", help="include bowls and the CFP")
    parser.add_argument("--json", metavar="PATH")
    parser.add_argument("--notion", action="store_true")
    parser.add_argument("--backtest", action="store_true")
    parser.add_argument("--show", metavar="TEAM", help="print one team's games and probabilities")
    args = parser.parse_args()

    if args.backtest:
        backtest(args.season)
        return

    games, fbs_ids, names = season_games(args.season, weeks=range(1, args.through_week + 1))
    if args.postseason:
        post, post_fbs, post_names = season_games(args.season, seasontype=3, weeks=range(1, 2))
        games += post
        fbs_ids |= post_fbs
        names.update(post_names)
    if not games:
        sys.exit("No completed games yet.")
    fcs_ids = {t for g in games for t in (g["home"], g["away"])} - fbs_ids
    ratings, hfa = fit_ratings(games, fbs_ids, fcs_ids)
    rows, bench = resume_table(games, fbs_ids, ratings, hfa)
    last_week = max(g["week"] for g in games if g["week"] < 100)
    try:
        sor = espn_sor(args.season)
    except RuntimeError:
        sor = {}

    print(f"{args.season} through week {last_week}: {len(games)} games, {len(rows)} FBS teams, "
          f"home field {hfa:.1f}, benchmarks high {bench['high']:+.1f} / mid {bench['mid']:+.1f} "
          f"/ low {bench['low']:+.1f}")
    if last_week < 4:
        print("Early season: the proposal publishes from week 4; these are provisional.")
    print(f"{'#':>3}  {'Team':<22} {'W-L':>5} {'Score':>6} {'Avg#':>5} {'Str':>6} {'SOR':>4}")
    for row in rows:
        print(f"{row['rank']:>3}  {names.get(row['team'], row['team']):<22} "
              f"{row['wins']}-{row['losses']:<3} {row['score']:>6.1f} {row['rank_mid']:>5} "
              f"{row['strength']:>+6.1f} {sor.get(row['team'], ''):>4}")
    pairs = [(r["rank"], sor[r["team"]]) for r in rows if r["team"] in sor]
    if pairs:
        print(f"Spearman vs ESPN SOR: {spearman(pairs):.3f} over {len(pairs)} teams")

    if args.show:
        row = next((r for r in rows if names.get(r["team"], "").lower() == args.show.lower()), None)
        if row:
            print(f"\n{names[row['team']]} {row['wins']}-{row['losses']}, high benchmark {bench['high']:+.1f}")
            for opponent, site in row["games"]:
                p = win_probability(bench["high"] - ratings[opponent] + hfa * site)
                where = {1: "vs", -1: "at", 0: "n."}[site]
                print(f"  {where} {names.get(opponent, opponent):<22} {ratings[opponent]:+6.1f}  p(win) {p:.3f}")
            print(f"  P(benchmark wins >= {row['wins']}) = {row['p_high']:.4f}")

    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"season": args.season, "through_week": last_week, "hfa": hfa,
                       "benchmarks": bench,
                       "rows": [{**{k: v for k, v in r.items() if k != "games"},
                                 "name": names.get(r["team"])} for r in rows]}, handle, indent=1)
    if args.notion:
        write_notion(rows, names)


if __name__ == "__main__":
    main()
