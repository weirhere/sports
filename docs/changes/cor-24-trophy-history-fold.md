---
date: 2026-11-06
---

## Decision

**The trophy case fetches its history the way the head-to-head tab does.** `ScoresProviding.seasons(of:from:through:)` is internal now, with two callers: the head-to-head series and the team page's Trophies tab. `loadTrophyHistory` asks for the league's season floor through now in one call. That is two requests a season (no preseason, which can't win a trophy) with three seasons in flight, about two dozen requests in four waves. The old sequential `load(year:)` loop made three dozen in twelve. The fetched games stay the shelf's own and never enter `schedules`. `TrophyCase.derive(from:teamId:league:)` is the new `[Game]` entry point. It groups by trophy *and* season, so one season's lost final can't decide another's. `TeamPage.trophyHistoryFailedWholesale` is gone: the Retry state is now the fetch throwing `ESPNError.nothingFetched`, which only happens when every season failed.

## Why

Two mechanisms were answering the same question, and the slower one was in the view. The trophy loop's one advantage was warming `schedules[year]` for the other tabs. It can't keep that: a preseason-less season in that cache would empty the Games tab's Preseason card.

**One change from the backlog's plan.** E15 said to read each trophy's season off the game's date (`SeasonYear.year(for:now:)`). That gets the pandemic seasons wrong. The 2019-20 NBA Finals ended October 11, 2020, a day the rollover rule files under 2020-21, and the Stanley Cup ran into September (`SeasonSpan.overruns`). The schedule payload stamps every event with its season, and `Game.seasonYear` already decodes it. So derivation reads the stamp first and uses the date only when the stamp is missing. A test pins the bubble Finals to 2019.

## Web parity

shipped — the web already worked this way. `teamTrophyCase` in `web/src/lib/espn/provider.ts` walks the seasons with the same `walkSeasons` pool that head-to-head uses, over the preseason-less `teamSeasonGames`, three at a time. It derives one season at a time, so it never had a season-stamp question to answer. iOS catches up here.

## Backlog

COR-24 (BACKLOG E15)
