# The StatSide résumé

The replacement for the StatSide rating's record sort, prototyped in Notion
first (Andy, 2026-10-27). The source is the ranking proposal "College Football
Ranking System — Initial Proposal". Only its résumé half is adopted; its
performance half (yards per play, success rate, explosive plays, red zone,
special-teams value) is not. Most of that needs play-by-play, which an
on-device app with no backend can't afford, and the résumé answers the
question the rating exists for.

`scripts/statside-resume.py` computes it. The app still ships the record sort
(`StatSideShared/Models/StatSideRating.swift`) until the port; see BACKLOG E22.

## The question

How unlikely would a **90th-percentile FBS team** be to match or beat this
team's record against this team's exact schedule? Home, away and neutral
sites all count. The less likely, the better the résumé.

- **One benchmark for everyone.** The headline benchmark is the 90th
  percentile because it separates contenders. A national-average benchmark
  is a secondary column. The three levels are never averaged.
- **The whole probability, not wins minus expected wins.** P(at least W wins)
  is computed as a Poisson-binomial over the team's games. Two schedules with
  the same expected wins can make 10-2 very differently hard.
- **No quality-win bonus.** Beating good teams already lowers the probability
  through the record against the schedule. A bonus would count it twice.
- **Score** = 100 × (1 − P), on a 0–100 scale where higher is harder. **Rank**
  sorts by P ascending; ties break on the average-team P, then point
  differential.

## Opponent strength

Each opponent's strength is a rating, not a rank position. It is an
opponent-adjusted scoring margin fit to every completed Division I game of the
season (FBS scoreboards with `groups=80`, plus FCS-vs-FCS with `groups=81`):

```
capped margin(home) = r_home − r_away + HFA       (HFA = 0 at a neutral site)
```

It is solved by Gauss-Seidel until no rating moves more than 0.01. Each team
is pulled toward its group's mean by K phantom games: FBS toward 0, and FCS
and Division II visitors toward their own group means. Group means and
home-field advantage are re-estimated on every sweep. The fit is redone from
scratch each run, so early opponents get re-rated as their seasons play out.

| Constant | Value | Meaning |
|---|---|---|
| `CAP` | 35 | margins capped at ±35, which keeps garbage time out |
| `K` | 1.0 | phantom games of shrinkage toward the group mean |
| `SIGMA` | 16.0 | margin spread that turns a rating gap into a win probability |
| HFA | estimated | about 4 points in 2026 through week 8 |

## Backtest (`--backtest`)

For each week from 4 to the end of the regular season, the script fits on the
games played by then and predicts the next week's games that involve an FBS
team.

| Season | Constants | Straight-up | Brier |
|---|---|---|---|
| 2025 | chosen (35, 1, 16) | 72.3% | 0.1824 |
| 2025 | best on the grid (uncapped, 0.5, 18) | 72.8% | 0.1794 |
| 2025 | first guess (28, 2, 16) | 71.4% | 0.1856 |
| 2024 | chosen (35, 1, 16) | 71.3% | 0.1907 |
| 2024 | best on the grid (uncapped, 0.5, 20) | 70.8% | 0.1891 |
| 2024 | first guess (28, 2, 16) | 70.1% | 0.1926 |

Uncapped margins with almost no shrinkage predict a hair better. The chosen
constants give up less than 0.002 Brier for two things the proposal asks for:
garbage time doesn't move ratings, and thin early-season evidence stays near
average. The grid's optimum also sits at its edge (K = 0.5), which reads as
"shrinkage barely matters once FCS games connect everyone", not as a reason
to remove it.

How the résumé compares with the references at season's end, using the
chosen constants:

| Season | vs committee's final top 25 (regular season) | vs ESPN final SOR (with postseason) |
|---|---|---|
| 2025 | Spearman 0.912, 22 of 25 shared | 0.992 all FBS, 0.958 SOR's top 25 |
| 2024 | Spearman 0.902, 23 of 25 shared | 0.993 all FBS, 0.916 SOR's top 25 |

The biggest disagreements with the committee go one way. The résumé likes
unbeaten or one-loss Group of Five and Big 12 teams (2025 BYU 6th vs 12th,
James Madison 17th vs 24th; 2024 BYU 8th vs 17th, Arizona State 7th vs 12th).
The committee likes three-loss power-conference teams more (2025 Virginia,
Houston, Arizona; 2024 Ole Miss, Tennessee). That is the résumé's rule doing
what it says: the record against the schedule, with no brand.

**Benchmark sensitivity:** swapping the 90th-percentile benchmark for the
national average changed 2 of 25 top-25 teams in 2025 and 1 in 2024. The
secondary column barely moves the ranking. It stays in Notion for now as a
cheap check, and need not come to the app.

## In Notion

The College Football Teams 2026 database has four columns: **Résumé Rank**,
**Résumé Score**, **Résumé Rank (Avg Team)** and **Strength**. Its **StatSide
Résumé** view sorts FBS by the résumé beside ESPN's SOR Rank, the Performance
Poll's Perf Rank and the AP rank. To refresh:

```
scripts/statside-resume.py --notion     # needs NOTION_TOKEN
```

Without a token, `--json` writes the table, and a Claude session can push it
through the Notion connector. Perf Rank stays alongside until the app port
retires or redefines it.
