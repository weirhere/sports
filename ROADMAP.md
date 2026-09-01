# ROADMAP.md — sports

## North star

The fastest, calmest way to follow college football on a Saturday. One screen tells you the state of the sport; your teams are always at the top; nothing gets between you and the score.

## The clock we're building against

The 2026 season kicks off late August (Week 0, ~Aug 22; full Week 1 slate Labor Day weekend). That's roughly 5 weeks out. The plan is deliberately shaped so a usable scores app exists before kickoff, because **the fall is the research phase**: live with the app every Saturday, and let real use decide what gets built next. Understand → grow → build, on repeat.

## Phases

### Phase 0 — Foundation (repo hygiene)
Deployment target to iOS 18.0, folder structure, monochrome theme tokens (light + dark), ESPN client with defensive DTO decoding, domain models.

**Exit:** app builds and runs on an iOS 18 simulator; theme renders in both modes; client fetches and decodes a real scoreboard.

### Phase 1 — The Scores screen (the product)
Week strip (Wk 0–14, CCG, Bowls, CFP labels from ESPN's calendar), section stack (Following → Top 25 → conferences as accordions), game rows (pre/live/final variants), conference jump chips, Live toggle, accordion memory, pull-to-refresh + 30s live polling.

**Exit:** on a game day, you can open the app and know everything that matters in under 5 seconds without a single navigation. This phase must ship before the season starts.

### Phase 2 — Depth (tap into a game)
Game detail: line score by quarter, scoring plays, team stats comparison, leaders. Rankings screen: AP default, Coaches/CFP picker, movement arrows.

**Exit:** the two taps a fan actually makes (a game, the poll) both land somewhere worth landing.

### Phase 3 — Yours (identity)
Team browse/search, follow/unfollow, Following section powered by real follows, team page with schedule and record. Conference list ordering personalizes (your team's conference floats up).

**Exit:** two different users see two meaningfully different apps.

### Phase 4 — Season hardening (during the season)
Whatever the Saturdays reveal: polling behavior under 50 concurrent games, row legibility in sunlight, empty/error states, offseason and bye-week states, week rollover edge cases, performance passes.

**Exit:** driven by field notes, not a spec.

## Explicitly later (do not build yet)

- **Widgets / Live Activities** — probably the killer feature for this app (lock-screen live score for your team), but only after the in-app row design is proven.
- **Notifications** (kickoff, close game, final) — needs a backend or Live Activity push story; big lift.
- **Other sports** (CBB is the natural second: same schools, same follows, same conference model, and it fills December–March).
- **FCS and lower divisions.** *(Scoped 2026-09-01 as BACKLOG E8 — 14 conferences, 116 teams, all reachable via ESPN group 81; the epic is written, the go/no-go is its first item. Still not scheduled.)*
- **News/media content** — FotMob has it; we may never want it. Scores-first identity is the differentiator.
- **Any monetization or App Store release** — forces the data-licensing question (ESPN's API is not licensable; CFBD or a paid provider would be the path).

## Standing risks

| Risk | Posture |
|---|---|
| ESPN API changes/breaks without notice | Contained: DTO isolation, all-optional decoding. If it dies mid-season, swap to CFBD behind the same domain models |
| Seasonality (Feb–Aug is dead air) | Accepted for v1. Offseason landing state in Phase 4; CBB expansion is the real answer later |
| One-person project, 5-week runway | Phases 0–1 are the only hard commitment before kickoff; 2–3 can land mid-season |
