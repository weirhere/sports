---
name: ui-change
description: Make a UI change to the iOS app the way Andy asked for it to be made from 2026-10-19 on — write the expected visual outcome first, implement, re-record only the affected snapshot baselines, build a before/after HTML report in /tmp/ui-report, verify the installed build on the dedicated simulator by screenshot, and iterate up to five times before asking. Use for any request that changes how a screen, card, row, header or strip looks.
---

# A UI change, start to finish

Andy's standing instruction (2026-10-19): *"for any UI change I request: write
down the expected visual outcome first; implement it; re-record only the
affected snapshots; generate a side-by-side before/after HTML report in
/tmp/ui-report; and verify the installed build on a dedicated simulator by
screenshot. If the result doesn't match my description, for example a divider
in the wrong place or uneven padding, iterate up to 5 times before asking me."*

The pieces exist; this is the order they run in. Every phase ends with
something you can look at.

## What's covered by baselines

`sportsTests/Snapshots/ComponentSnapshotTests.swift` holds pixel baselines
(pointfreeco/swift-snapshot-testing, the test target's one dependency) for:

| Test | Component | Data |
|---|---|---|
| `startersCard` | `FormationCard` — the Roster tab's Starters section, field layout | Georgia at Alabama live; Celtics at Knicks final; Maple Leafs at Bruins on the ice |
| `gameHeaderExpanded` | `GameHeader` — the game page's header on the page | same three games: live with the ball, final, pre-game |
| `gameHeaderCompact` | `CompactGameHeader` — the bar's scoreboard once it has scrolled under | same |
| `dayStrip` | `DayStrip` — the Scores screen's axis | "Today" pinned to a football Saturday, a January weeknight, a March Saturday |

Each runs on an iPhone 17 Pro (402pt, 3x) and an iPhone SE (375pt, 2x), light
and dark: 12 PNGs a component, 48 in all, under
`sportsTests/Snapshots/__Snapshots__/ComponentSnapshotTests/`, named
`<test>.<sport>-<device>-<scheme>.png`. The data is hand-built in
`SnapshotFixtures.swift` with every URL nil, so a mark is always the
placeholder disc and a headshot is always the number.

A change to a surface that has no baseline gets one first, in the same
shape: a `@Test(arguments: Variant.all)` in the suite, data in the fixtures,
recorded before the change so the report has a before. That is the one case
where a new baseline is committed on its own before any UI moves.

## Phase 0 — Write the expected outcome

Before touching a view, write what the screen will look like when it is
right, in Andy's terms, as a short file in the scratchpad (or straight into
the report with `--expected`). Concrete and checkable: which element moves,
to where, by how much; what sits above and below it; what stays put. "The
possession chips are their own row under the title, 8pt above and below,
with a hairline between in the surface's ink" is checkable. "Tidier" is not.

This is the text the report opens with, and the text Phase 4 is checked
against — so if the request is ambiguous about a measurement, say which
reading you took here rather than discovering it in the screenshot.

## Phase 1 — Implement

As usual: `docs/decisions.md` first if the surface has history, one view per
file, the color budget, `docs/web-parity.md` row with the decisions row.
Check the web needs the same change and say so.

## Phase 2 — Re-record only the affected baselines

```bash
scripts/snapshot-tests.sh --record --filter <test>
```

One `--filter` per component the change touches, never a bare `--record`:
a baseline that moved for a change that shouldn't have moved it is the
signal, and re-recording everything throws it away. After recording,
run the comparison for everything to see what else moved:

```bash
scripts/snapshot-tests.sh
```

Anything red that the change didn't mean to touch is a finding, not a
re-record. The baselines are iOS 26.5 iPhone 17 Pro pixels; the script owns
the simulator ("iPhone 17 Pro snapshot-tests") and the `STATSIDE_SNAPSHOTS=1`
gate, and prints the result bundle path, which holds the reference, failure
and difference images for anything that failed.

## Phase 3 — The report

```bash
scripts/ui-report.py --expected-file <phase-0 file>
open /tmp/ui-report/index.html
```

Before is the committed PNG (`HEAD`, or `--base <ref>`), after is the working
tree, so it reads straight off the `--record` — nothing needs committing
first. Changed pairs get a magenta difference image and a changed-pixel
percentage; unchanged files are listed under a disclosure. Look at it
yourself (`Read` the PNGs under `/tmp/ui-report/img/`) before Andy does.

## Phase 4 — The installed build, by screenshot

```bash
scripts/verify-sim.sh                     # build + install + launch + screenshot of the launch screen
scripts/verify-sim.sh --dark --name dark  # the same, dark
```

That is the Scores screen. For anything deeper, drive the same device —
the iOS Simulator tool in the session takes `device: "iPhone 17 Pro snapshot-tests"`
for `tap`, `swipe`, `text` and `screenshot` — and name the picture with
`scripts/verify-sim.sh --shot-only --name <what>`. Then add it to the page:

```bash
scripts/ui-report.py --expected-file <phase-0 file> --sim /tmp/ui-report/sim-<what>.png
```

Deep links don't help here: `statside://` is deliberately unregistered, so
`simctl openurl` can't open a game. Tap to it.

The screenshot is the check against Phase 0. Read it with the expected
outcome beside it and look for the things Andy names: a divider in the
wrong place, uneven padding, a row that moved when it shouldn't have,
something that changed in dark and not in light. Snapshots are
components at a width; the simulator is the component in the page, under
the real bar, with the real tab row above it.

## Phase 5 — Iterate, up to five times

A mismatch goes back to Phase 1, with the expected outcome unchanged unless
the mismatch shows the expectation itself was wrong (then say so). Count the
rounds. After the fifth that still doesn't match, stop and show Andy the
report with what is off and what was tried — not before. A round is a code
change plus Phases 2–4, not a re-read of the same screenshot.

## Phase 6 — Commit

The baselines go in the same commit as the change that moved them, so a
`git log` on a PNG explains it. The decisions row, the parity row and the
report's expected-outcome text agree with each other.

## Ground facts

- Simulator: "iPhone 17 Pro snapshot-tests", iPhone 17 Pro, iOS 26.5, created on
  demand by both scripts. It is this workflow's; other sessions' installs
  on the shared devices never reach it. It persists shut down between
  sessions; `xcrun simctl delete` it only if the runtime goes away.
- Record mode is the library's `SNAPSHOT_TESTING_RECORD=all`, passed through
  `xcodebuild` as `TEST_RUNNER_SNAPSHOT_TESTING_RECORD`. A record run
  "fails" every test by design; the script reads the log and exits 0.
- The suite skips itself unless `STATSIDE_SNAPSHOTS=1`, so CI (any runner,
  any runtime) runs the rest of `sportsTests` untouched. Run it in Xcode
  by adding the variable to the scheme's test environment.
- `drawHierarchyInKeyWindow: true`: the views render in the host app's
  window, which is what makes `LogoImage`, `LiveDot` and the SwiftUI
  `NavigationLink`s draw as they do on a device.
- The compact header is snapshotted as the bar draws it (card color,
  hairline) without the system chrome either side; a toolbar's principal
  item can't be hosted in an offscreen render.
