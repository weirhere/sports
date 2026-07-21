# ARCHITECTURE.md — sports

## Shape of the app

SwiftUI, MVVM-lite, no backend. Three layers, dependencies point one way:

```
Views (Features/*)          — SwiftUI, dumb, render domain models
  ↓
Stores & ViewModels         — @Observable, own state + orchestration
  ↓
Networking + Models         — ESPNClient (DTOs) → domain models
```

ESPN's JSON shapes never leave the networking layer. Views never see a DTO.

## Folder layout

```
sports/
  App/
    sportsApp.swift          — entry point (exists)
    RootView.swift           — TabView: Scores | Rankings | Teams
  Theme/
    Theme.swift              — semantic colors (mono ramp + liveAccent), spacing, type styles
  Models/
    Game.swift               — Game, GameStatus (pre/live/final), Competitor, Broadcast
    Team.swift               — Team, Conference (id map)
    Ranking.swift            — Poll, RankedTeam, Trend
    Week.swift               — WeekSlot (regular(n) | ccg | bowls | cfp), from ESPN calendar
  Networking/
    ESPNClient.swift         — endpoints, URLSession, decode → map to domain
    ESPNDTOs.swift           — Codable structs mirroring ESPN JSON, everything optional
  Stores/
    FollowingStore.swift     — Set<Team.ID> in UserDefaults
    UIStateStore.swift       — accordion expansion, last poll choice, in UserDefaults
    ScoreboardStore.swift    — current week, games, polling loop, section grouping
  Features/
    Scores/                  — ScoresScreen, WeekStrip, ConferenceChips, SectionAccordion,
                               GameRow (+ Pre/Live/Final variants), LiveDot, DayDivider
    Rankings/                — RankingsScreen, PollPicker, RankRow
    GameDetail/              — GameDetailScreen, LineScoreGrid, ScoringPlaysList, TeamStatsCompare
    Teams/                   — TeamsScreen (browse/search), TeamPage, FollowButton
```

Files added here are auto-included in the target (synchronized root group, `objectVersion 77`).

## Key mechanics

### Week model
ESPN's `leagues[0].calendar` provides labeled periods (Regular Season, Postseason) whose `entries[]` carry `label`, `value`, `startDate`, `endDate` per week. Parse once per launch into `[WeekSlot]` and drive the strip from it — never hardcode week counts (Week 0 exists some years, CFP rounds shift). Current week comes from top-level `week.number` + `season.type`.

**Rollover rule:** the strip's default selection is the ESPN current week, except Sundays, where we pin to the week that just completed (Sunday is catch-up + new poll day; flip Monday morning). Implement as: if today is Sunday and ESPN says week N+1, show N.

### Section grouping
`ScoreboardStore` groups one week's games into ordered sections:

1. **Following** — any game where either competitor ∈ FollowingStore (skip section if empty)
2. **Top 25** — any game where either competitor has `curatedRank.current ≤ 25`
3. **One section per conference** — via `team.conferenceId`, ordered by relevance: followed team's conference first, then Power 4, then Group of 5, then Independents; unknown ids bucket into "Other"

Games intentionally appear in multiple sections. Within a section: chronological, with day dividers (Thu/Fri/Sat) only when the section spans multiple days. Conference chips scroll-anchor to sections (`ScrollViewReader`), never filter. The Live toggle is the only filter: it collapses each section to in-progress games and hides empty sections.

Conference id map (hardcode with an "Other" fallback; ids verified against ESPN groups): ACC 1, American 151, Big 12 4, Big Ten 5, C-USA 12, Independents 18, MAC 15, Mountain West 17, Pac-12 9, SEC 8, Sun Belt 37, FBS umbrella 80.

### Live updates
- Foreground + at least one live game: re-fetch scoreboard every 30s (`Task.sleep` loop, cancelled on background/scene change).
- No live games: no polling; pull-to-refresh only.
- Diff by event id and update in place so accordion/scroll state survives refreshes.

### Persistence
UserDefaults only. Keys: `following.teamIds: [String]`, `ui.expandedSections: [String]`, `ui.pollChoice: String`. No cache of API responses in v1 beyond in-memory (URLCache gets default behavior for free).

### Theme
Semantic tokens, never raw colors in views: `.bgPrimary`, `.bgElevated`, `.textPrimary`, `.textSecondary`, `.divider`, `.liveAccent` (the red dot — the app's only accent). Light and dark are the same design inverted. Scores use `.monospacedDigit()`. Logos load via `AsyncImage` from ESPN's logo URLs (full color, the monochrome exception).

### Concurrency note
Project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. `ESPNClient` should be explicitly `nonisolated`/`actor` so decoding stays off the main thread; everything else defaulting to MainActor is fine at this app's scale.

## API reference (shapes verified live 2026-07-21)

Base: `https://site.api.espn.com/apis/site/v2/sports/football/college-football`

### `/scoreboard?groups=80&limit=300&week={n}&seasontype={2|3}`
- Top level: `leagues[]`, `season{type,year}`, `week{number}`, `events[]`
- `leagues[0].calendar[]`: `{label, value, startDate, endDate, entries[{label, alternateLabel, detail, value, startDate, endDate}]}`
- `events[]`: `id, date, name, shortName, week{number}, status, competitions[]`
- `events[].status`: `clock, displayClock, period, type{id, name, state ("pre"|"in"|"post"), completed, detail, shortDetail}`
- `competitions[0].competitors[]`: `homeAway, score (string), records[{name, abbreviation, type, summary}], curatedRank, team{id, location, name, abbreviation, displayName, shortDisplayName, color, alternateColor, logo, conferenceId}`
- Network: `competitions[0].broadcasts[{market, names[]}]` and convenience string `broadcast`

### `/rankings`
- `rankings[]`: `{id, name, shortName, type, occurrence, headline, ranks[]}` — AP, Coaches, CFP when in season
- `ranks[]`: `{current, previous, points, firstPlaceVotes, trend, recordSummary, team{id, location, name, nickname, abbreviation, color, logo, logos[]}}`
- Movement = `previous` − `current`; `trend` is also provided as a string

### `/summary?event={id}`
- `boxscore.teams[]`: `{team, homeAway, statistics[{name, label, displayValue, value}]}`
- `boxscore.players[]`: per-team `statistics[]` with `labels[]`, `athletes[{athlete{displayName, jersey, headshot}, stats[]}]` — leaders/box score source
- `scoringPlays` via `drives.previous[].plays[]` (`scoringPlay: true`) and a top-level `scoringPlays[]` when present: `{period, clock, text, awayScore, homeScore, team, type}`
- `header.competitions[0].competitors[].linescores[]` — per-quarter line score
- `gameInfo`: `{venue{fullName, address}, attendance}`
- `drives.previous[]`: full drive log (`result`, `yards`, `offensivePlays`, `timeElapsed`) — future drive-chart material, not v1

### Teams + schedules (shapes verified live 2026-07-20)

**`/teams?limit=1000` is useless for browse**: it returns all 755 teams across every division with *no conference data*, and ignores `groups=` filters. Conference membership comes from the standings API instead:

- **`https://site.api.espn.com/apis/v2/sports/football/college-football/standings?group=80`** (note: `apis/v2`, not `apis/site/v2`) — one request returns 11 FBS conference `children[]`, each with `standings.entries[].team` carrying id, names, and `logos[]`. This is the Teams-browse source. Offseason quirk: a conference can have zero entries (Sun Belt did on 2026-07-20); render what's there.

**`/teams/{id}/schedule`** — quirks vs. the scoreboard shape, all handled in dedicated DTOs:
- `score` is an object `{value, displayValue}`, not a string
- `record` is an array (type `total` carries the summary), not `records`
- `status` lives on `competitions[0]`, not the event
- broadcasts nest as `broadcasts[].media.shortName`
- 2026 schedules unpublished as of July (`events: []`); pass `?season=2025` for last season

### `/summary` extras
`leaders[]` at the top level (per team: `passingYards`/`rushingYards`/`receivingYards` categories with `athlete` + `displayValue`) is the game-detail leaders source — simpler than reassembling from `boxscore.players`. Header competitors carry `linescores[].displayValue` and a `record` array.

## Failure posture

- Every DTO field optional; a partial row renders partially (no network? show time TBD; no record? omit it). Decode failure of one event drops that event, never the screen.
- Screen-level states: loading (skeleton rows), error (retry button, last-good data if any), empty (offseason/bye messaging).
- If ESPN breaks mid-season: domain models are the contract; write a CFBD-backed client conforming to the same protocol (`ScoresProviding`) and swap. Design `ESPNClient` behind that protocol from day one — it costs nothing now and is the whole insurance policy.
