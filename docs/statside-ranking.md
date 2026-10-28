# The StatSide ranking

FBS ranked two-thirds on **résumé** and one-third on **performance**. This is
the system from the proposal "College Football Ranking System — Initial
Proposal", which Andy adopted on 2026-10-27. It was prototyped in Notion
first. `scripts/statside-ranking.py` computes it and writes it to the College
Football Teams 2026 database.

The app still ships the record sort (`StatSideShared/Models/StatSideRating.swift`)
until the port; see BACKLOG E22.

The proposal, section by section, and where each part lives:

| Proposal | Here |
|---|---|
| Two scores kept visible, weighted 2/3 résumé, 1/3 performance | § Overall, Notion's Résumé and Performance columns beside Overall |
| Performance: yards per play, success rate, explosive plays, red zone, points per meaningful possession | § Performance: offense and defense |
| Special teams: punting, kickoffs and returns, field goals, extra points | § Performance: special teams |
| Opponent adjustment: numeric ratings, iterated until they settle, shrunk early, re-rated weekly | § Opponent adjustment |
| Résumé: a fixed benchmark team, the exact schedule, location, the probability of matching the record | § Résumé |
| Benchmarks: high is the headline, mid is secondary, low is a diagnostic; sensitivity tested | § Résumé, § Backtest |
| Comparable scales before combining | § Overall |
| Publish from week 4 | `--notion` refuses earlier weeks without `--force` |
| Publish overall, résumé, performance, offense/defense/special teams, conferences | Notion columns; § Conferences |
| Backtest with only the information available each week; performance judged on predicting games | § Backtest |
| Publish definitions, weights and the adjustment method | this file, and each Notion column's description |

## Résumé

The résumé asks how unlikely a **90th-percentile FBS team** would be to match
or beat this team's record against this team's exact schedule. Home, away and
neutral sites all count. The less likely, the better the résumé.

- **One benchmark for everyone.** The 90th percentile is the headline because
  it separates contenders. A national-average benchmark is the secondary
  column, and the 25th percentile is a diagnostic. The three are never
  averaged.
- **The whole probability, not wins minus expected wins.** P(at least W wins)
  is a Poisson-binomial over the team's games. Two schedules with the same
  expected wins can make 10-2 very differently hard.
- **No quality-win bonus.** Beating good teams already lowers the probability
  through the record against the schedule. A bonus would count it twice.
- **Résumé Score** = 100 × (1 − P), on a 0–100 scale where higher is harder.
  **Résumé Rank** sorts by P ascending; ties break on the average-team P, then
  point differential.

Each opponent's strength is a rating, not a rank position: an opponent-adjusted
scoring margin fit to every completed Division I game (FBS scoreboards with
`groups=80`, plus FCS-vs-FCS games with `groups=81`):

```
capped margin(home) = r_home − r_away + HFA       (HFA = 0 at a neutral site)
```

| Constant | Value | Meaning |
|---|---|---|
| `CAP` | 35 | margins capped at ±35, which keeps garbage time out |
| `K` | 1.0 | phantom games of shrinkage toward the group mean |
| `SIGMA` | 16.0 | margin spread that turns a rating gap into a win probability |
| HFA | estimated | about 4 points in 2026 |

## Performance: offense and defense

Five stats, read from ESPN's play-by-play (`/summary?event=`, every game with
an FBS team in it):

| Stat | Definition | Weight |
|---|---|---|
| Yards per play | `statYardage` per snap; an interception or lost fumble counts 0 | 0.25 |
| Success rate | 50% of the distance on 1st down, 70% on 2nd, all of it on 3rd and 4th; a touchdown always succeeds, a turnover never does | 0.30 |
| Explosive-play rate | runs of 12+ yards, passes (sacks included) of 16+ | 0.15 |
| Points per meaningful possession | 7 for a touchdown, 3 for a field goal; the offense's own scores only | 0.20 |
| Points per red-zone trip | the same points, over meaningful possessions with a snap inside the 20 | 0.10 |

The rules that make these consistent:

- **Snaps** are runs and passes on downs 1–4. Kneel-downs and spikes are
  excluded, and so are penalties called as no play.
- **Garbage time** is Bill Connelly's line: a lead of more than 38 points in
  the second quarter, 28 in the third or 22 in the fourth. Never in the first
  quarter or overtime. Snaps in garbage time don't count.
- **Meaningful possessions** have at least one real snap, start in regulation
  outside garbage time, and aren't cut off by the end of a half or game.
  Overtime possessions start on the 25, so they don't count toward possession
  or red-zone stats, though their snaps count toward the per-play ones.
- **Weights.** Red zone gets modest weight because trips are few. Points per
  possession gets less than the per-play stats because it partly re-counts
  them, which is the proposal's warning about counting one strength several
  times.

Each stat is opponent-adjusted (below) and standardized across FBS. Offense is
the weighted sum of the five, and so is defense. A least-squares fit of each
game's capped margin on the teams' offense and defense gaps, with home field
and special teams taken out, scales the two sums into **points per game
against an average FBS team on a neutral field**.

## Performance: special teams

All in points, against league baselines rebuilt from the same games each run:

- **Field position value.** A possession starting *y* yards from the end zone
  is worth the average points meaningful possessions starting there score:
  1.3 from your own 1, 1.9 from your 25, 3.1 from midfield, 4.1 from the
  opponent's 25 (2026, smoothed with a Gaussian kernel).
- **Punts and kickoffs.** Each kick is worth (expected receiving value from
  that kick spot) − (actual) to the kicking team. The actual value is the
  field-position value of the receiving team's **next snap**: ESPN's kick end
  spots are unreliable, with a third of 2024's flipped or wrong. A return
  touchdown is worth 7 to the receivers, and a kick the kicking team recovers
  is worth minus its own field-position value. A kick's value includes the
  coverage and the other team's returner. So returns show in the breakdown,
  but they count toward a team's rating only through the other side's kicks.
  That way one kick is never counted twice.
- **Field goals** are worth 3 × (made − expected makes at that distance), and
  blocked kicks count as misses. Expected makes run from 86% at 20 yards to
  54% at 50, again smoothed from the season's own kicks.
- **Extra points** are counted separately: made − the league rate (97.6%).

A team-game's special-teams points are its own kicks, field goals and extra
points. The rating is the opponent-adjusted margin of those points, fit the
same way as the scoring margin (`ST_K` phantom games of shrinkage, no cap).

**Performance** = Offense + Defense + Special Teams.

## Opponent adjustment

Every stat is fit, not averaged. For a team on offense against an opponent's
defense in one game:

```
stat = league mean + offense[team] − defense[opponent] + home × site
```

The fit is weighted by snaps, or by possessions or trips for those two stats.
It is solved by Gauss-Seidel until the moves are under 1/10,000 of the stat's
spread. The rules:

- Each unit is pulled toward its group's average by `UNIT_K` games' worth of
  weight: FBS toward the FBS average, FCS toward the FCS average.
- Both sides are centered on the average FBS unit.
- Home field is estimated jointly.
- The whole fit is redone every run, so a September opponent is re-rated by
  what it did in October.

Teams are rated nationally first. Conferences come only afterward, from the
team ratings, with no conference-strength bonus anywhere.

## Overall

The résumé and performance are put on comparable scales before they're
combined:

- **The résumé** becomes standard deviations: the probit of 1 − P, so a 1-in-20
  record reads +1.6. Then it is standardized across FBS.
- **Performance** is standardized across FBS.
- **Overall** = 2/3 × résumé z + 1/3 × performance z. **Overall Score** reads
  that number as a 0–100 normal percentile.
- **Conf Rank** is a team's place inside its conference by Overall Rank.

## Conferences

Conferences are ranked by their teams' average Performance. The script also
prints average offense, defense, special teams and margin rating, how many
teams are in the overall top 25, and each conference's best team. The table
is printed by every run and saved in `--json`, and it is in the Notion page
"StatSide conference ratings".

## Backtest (`--backtest`)

For every week from 4 to the end of the regular season, the script fits on
the games played by then and predicts the next week's games that involve an
FBS team. The proposal judges performance ratings by how well they predict,
and that is the test here.

**The margin rating behind the résumé:**

| Season | Constants | Straight-up | Brier |
|---|---|---|---|
| 2025 | chosen (35, 1, 16) | 72.3% | 0.1824 |
| 2025 | best on the grid (uncapped, 0.5, 18) | 72.8% | 0.1794 |
| 2024 | chosen (35, 1, 16) | 71.3% | 0.1907 |
| 2024 | best on the grid (uncapped, 0.5, 20) | 70.8% | 0.1891 |

Uncapped margins with almost no shrinkage predict a hair better. The chosen
constants give up less than 0.003 Brier for two things the proposal asks for:
garbage time doesn't move ratings, and thin early-season evidence stays near
average.

**Performance**, on a grid of `UNIT_K` ∈ {1, 2, 4}, `ST_K` ∈ {2, 6} and σ ∈ {12…18}:

| Season | Rating | Straight-up | Brier |
|---|---|---|---|
| 2025 | performance (1, 6, 14) | 71.9% | 0.1853 |
| 2025 | performance + margin, averaged | 72.1% | 0.1815 |
| 2024 | performance (1, 6, 14) | 70.2% | 0.1891 |
| 2024 | performance + margin, averaged | 70.4% | 0.1879 |

On its own, performance predicts about as well as the margin rating. That is
the point of it: it gets there from how teams played rather than from the
scoreboard. **Averaged with the margin rating, it beats both in both
seasons**, so the play-by-play carries information the scores don't.
`ST_K = 6` won 2024 clearly and cost 2025 almost nothing. Special teams are
noisy, so they shrink harder than the offense and defense stats do.

**The composite against its parts** (2025 / 2024 Brier, at the first-pass constants):

| Weighting | 2025 | 2024 |
|---|---|---|
| chosen (0.25 / 0.30 / 0.15 / 0.20 / 0.10) | 0.1849 | 0.1914 |
| equal | 0.1859 | 0.1912 |
| points per possession only | 0.1869 | 0.1934 |
| per-play stats only | 0.1865 | 0.1940 |

The five stats together beat points per possession alone and the per-play
stats alone in both seasons. Equal weights are as good as the chosen ones in
2024 and worse in 2025, so the chosen weights stay. They are a judgment
call, published here as the proposal asks, not a fitted optimum.

**The rankings at season's end against the references:**

| Season | Ranking | vs committee's final top 25 | vs ESPN (with postseason) |
|---|---|---|---|
| 2025 | résumé | Spearman 0.912, 22 of 25 shared | SOR 0.992 (all FBS), 0.958 (SOR's top 25) |
| 2025 | performance | 0.755, 20 of 25 | FPI 0.958, 0.881 |
| 2025 | overall | 0.896, 22 of 25 | SOR 0.984, 0.922 |
| 2024 | résumé | 0.902, 23 of 25 | SOR 0.993, 0.916 |
| 2024 | performance | 0.784, 17 of 25 | FPI 0.961, 0.827 |
| 2024 | overall | 0.946, 21 of 25 | SOR 0.986, 0.802 |

The overall ranking's biggest disagreements with the committee go one way.
It rates unbeaten and one-loss teams from outside the power conferences
higher than the committee did: 2025 James Madison was 17th here and 24th for
the committee, and 2025 Vanderbilt 8th against 14th. It rates three-loss
power-conference teams lower: 2025 Houston was 39th here and 21st for the
committee, and 2024 Illinois 28th against 20th. That is the record against
the schedule doing what it says, with no brand.

**Benchmark sensitivity.** Swapping the 90th-percentile benchmark for the
national average changed 2 of the résumé's top 25 in 2025 and 1 in 2024. The
headline benchmark stays the 90th percentile, as proposed. The average-team
column is a cheap check rather than a second ranking.

**2026 through week 9** (1043 games, 568 with play-by-play):

- Résumé vs ESPN SOR: Spearman 0.981.
- Performance vs ESPN FPI: Spearman 0.933.
- Home field: 4.2 points.

ESPN's play-by-play is missing for a few games: 2 of 934 in 2025 and 18 of
919 in 2024. Those games count toward the résumé but not toward performance.

**Not done, and worth trying next.** The résumé's win probabilities come
from the margin rating alone. Averaging in performance predicted better in
both seasons, so using that average as the opponents' strength would sharpen
the résumé. It would also make the résumé depend on play-by-play, so it is
left as a decision for Andy rather than taken here.

## In Notion

The College Football Teams 2026 database has these columns:

- **Overall Rank** and **Overall Score**
- **Résumé Rank**, **Résumé Score**, **Résumé Rank (Avg Team)** and
  **Strength**
- **Performance Rank** and **Performance**, with **Offense**, **Defense**
  and **Special Teams** behind it
- **Conf Rank**

Its views:

- **StatSide Ranking** sorts FBS by Overall Rank, beside ESPN's SOR Rank and
  FPI Rank and the AP rank.
- **StatSide Résumé** is the résumé alone.
- **StatSide by conference** groups the ranking by conference.

**Perf Rank**, the record sort behind the "Performance Poll" view, is
untouched; the new performance is **Performance Rank**. To refresh:

```
scripts/statside-ranking.py --notion     # needs NOTION_TOKEN; week 4 on
```

`--notion` also replaces the body of the "StatSide conference ratings" page
(`NOTION_CONFERENCE_PAGE`) with the week's table. That REST path hasn't run
yet: the 2026-10-28 refresh had no token and went through the connector.

Without a token, `--json` writes every column under `notion` for each row,
plus the conference table, and a Claude session can push it through the
Notion connector.
