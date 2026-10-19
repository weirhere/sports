---
name: parallel-ui
description: Run several isolated UI tasks at once, each in its own worktree on a ui/<slug> branch with its own cloned simulator and DerivedData — implement, unit-test, shoot light and dark screenshots of the football, basketball and hockey surfaces, open a PR with the shots embedded and auto-merge on, then tear the lane down. Use when Andy lists two or more UI changes and wants them done in parallel, or says "parallel-ui", "fan these out", "one PR each".
---

# Parallel UI tasks

One lane per task. A lane is a worktree, a branch, a simulator and a
DerivedData directory that nothing else touches. `scripts/parallel-ui-task.sh`
is the lane; this skill is how you run several of them side by side and
what each one owes the PR it opens.

**Why lanes, not the shared simulators.** Every booted iPhone on this Mac
belongs to some session, and `install-all-sims.sh` plus the Stop hook push
whatever tree they run from onto all of them. Two sessions verifying on one
device see each other's builds (see the `simulators-shared-across-sessions`
memory). A lane never says `booted`; it names its UDID every time.

## Ground facts

- Project `sports.xcodeproj`, scheme `sports`, product `StatSide.app`,
  bundle `com.andyryanweir.sports`. Unit tests are the `sportsTests`
  target; the capture suite is `sportsUITests/SurfaceScreenshotTests`.
- Branch `ui/<slug>`; worktree `.claude/worktrees/ui-<slug>` under the
  main checkout; simulator named `ui-<slug>`; DerivedData at
  `<worktree>/build/DerivedData` (`build/` is gitignored).
- `simctl clone` needs a **shut-down** source. The stock iPhone 17 Pro is
  booted and shared, so the script clones a shut-down iPhone 17 Pro on
  iOS 26 if one exists, else any shut-down iOS 26 iPhone, else creates a
  fresh iPhone 17 Pro. Say which happened in the PR body.
- Screenshots are PNGs the PR embeds from the `ui-screenshots` branch
  (orphan, never merged, one directory per slug, linked by commit SHA).
  `publish-shots` does this and prints the Markdown table to paste.
- The capture test and the script must be on the branch the lane is cut
  from. `up` refuses a base that lacks `SurfaceScreenshotTests.swift`.
- The repo allows squash merges and auto-merge. CI on a PR is
  `.github/workflows/ci.yml` (build + unit tests on a macOS runner) and
  `web-ci.yml` (parity ledger check: a decisions row needs a ledger row).

## Orchestrating

1. **Slugs first.** One kebab-case slug per task, from the change not the
   screen (`live-dot-weight`, not `scores`). Check `BACKLOG.md`: a change
   that isn't on it gets a row before code (CLAUDE.md § Don'ts).
2. **Preflight once**, before any agent starts:
   ```bash
   xcrun simctl list devices booted
   git -C "$(git rev-parse --show-toplevel)" worktree list | grep ui- || true
   ```
   Note which devices are already booted — those are other sessions' and
   nothing below may install on them. A leftover `ui-<slug>` lane from an
   earlier run is torn down with `down` before it is reused.
3. **One sub-agent per task**, launched in the same message so they run
   concurrently. Each brief is self-contained: the slug, the change in
   Andy's words, the lane procedure below verbatim, and the PR contract.
   Give it the `developer` agent type. Three lanes build three apps and
   drive three simulators at once; on a laptop, cap at three.
4. **Collect**: each agent reports PR URL, simulator UDID, CI state at the
   time of reporting, and the local paths of its shots. Verify each PR
   exists with `gh pr view <url> --json state,autoMergeRequest,statusCheckRollup`
   before putting it in the table — a report is not a PR.
5. **Report** one table: task, PR link, CI status, screenshot paths (local
   `build/shots/{light,dark}` and the `ui-screenshots` SHA). Then say what
   each lane left behind, if anything (a sim it couldn't delete, a
   worktree with uncommitted work).

## The lane, in order (what each agent runs)

All commands from the main checkout or any worktree of it; the script
finds the common git dir itself.

```bash
S=scripts/parallel-ui-task.sh; SLUG=<slug>
$S up $SLUG            # worktree + branch from origin/main, cloned sim booted; prints UDID
```

Record the `udid` line. It goes in the PR body and in every manual
`simctl` call you make; never `booted`.

**Implement** in `.claude/worktrees/ui-$SLUG`. Read `docs/decisions.md`
(`tail -40` at least) before changing product behaviour; the design
system and the color budget in CLAUDE.md apply. SwiftUI only, one view per
file, no new packages.

```bash
$S build $SLUG         # xcodebuild into <wt>/build/DerivedData for this sim only
$S install $SLUG       # install + launch on this UDID
$S test $SLUG          # sportsTests on this sim; fails the lane if red
$S shots $SLUG         # light then dark: SurfaceScreenshotTests → <wt>/build/shots/{light,dark}/*.png
```

`shots` sets the simulator's appearance itself and resets it to light.
It prints any `MISSING SURFACE` lines — a league with no reachable game
page (preseason, a search that didn't land). Fix with `SHOT_TEAM_NBA=…`
etc., or say in the PR which surface is missing and why. The set is the
Scores slate, then per sport a team page, the game page, and the game's
Roster tab where it has one.

If the change is to a screen the capture doesn't visit, add a shot of it:
either extend the walk in `SurfaceScreenshotTests` behind an env flag, or
take it by hand with `xcrun simctl io <udid> screenshot <wt>/build/shots/<mode>/<mode>-<name>.png`
in both modes so `publish-shots` picks it up.

```bash
$S publish-shots $SLUG # pushes the PNGs to ui-screenshots, prints the Markdown table
```

**Commit** on `ui/$SLUG`: every related change, including the docs rows
(below). Then open the PR and arm auto-merge:

```bash
git -C .claude/worktrees/ui-$SLUG push -u origin ui/$SLUG
gh pr create --base main --head ui/$SLUG --title "<what changed, as a sentence>" --body-file <body.md>
gh pr merge --auto --squash <pr-url>
```

```bash
$S down $SLUG          # shutdown + delete the sim, remove the worktree; the branch stays for the PR
```

`down` refuses a worktree with uncommitted changes. That is the check
that the commit happened; don't `FORCE=1` past it without reading
`git status` there first.

## The PR contract

The body follows `.github/pull_request_template.md` (Web parity, Backlog
closure, Verification) and adds two things:

- **Simulator**: the lane's device name and UDID, whether it was cloned
  (from which device) or created fresh, and the runtime. One line.
- **Screenshots**: the table `publish-shots` printed, under a heading.
  Light and dark for each surface. A missing cell says why.

Rows the PR owes elsewhere, in the same commit:

- `docs/decisions.md`: a dated row for any product-behaviour change, with
  the reasoning. Appended at the end.
- `docs/web-parity.md`: a row per decisions row (`shipped` / `pending` /
  `n/a` / `differs`). `web-ci.yml` fails without it. Say in the body
  whether `web/` needs the same change, even when you don't make it.
- `BACKLOG.md`: flip the row if this ships one.

Both docs tables conflict with main when several lanes merge in a row.
That is expected: merge main, keep both sides' rows, push. Auto-merge
picks the PR back up.

## Rules that aren't optional

- Never `simctl install booted`, `simctl ui booted`, or
  `install-all-sims.sh` from a lane. The UDID from `up`, every time.
- Never `cd` into another lane's worktree or touch another lane's files.
  Two lanes that need the same file are one task, not two.
- Don't chase CI failures that reproduce on `main`; note them in the body
  and move on (CLAUDE.md § PRs & CI).
- UI test rules from CLAUDE.md § Running the UI tests apply to the capture
  run: `-parallel-testing-enabled NO` is baked in; the suite pins
  `-ui.scoreFilter none`, `-ui.appearance system` and `-review.prompt off`.
- `down` always runs, even when the lane failed, unless the failure is in
  the worktree and Andy would want to look. Then say so and leave it, and
  still delete the simulator.
