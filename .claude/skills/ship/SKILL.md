---
name: ship
description: Land the current branch — commit everything related, push, open the PR in the repo's template, arm auto-merge, record the decision in docs/changes/, watch CI, report the URL. Use when Andy says ship, commit, commit and PR, open a PR, land this, or merge the PR.
---

# Shipping a branch

This is CLAUDE.md's default PR flow (§ Commits & branches, § PRs & CI) as one
command. Commit, commit-and-PR and merge-the-PR were the three most frequent
asks in the 2026-10-18 usage report, and every one of them walked the same
steps by hand. Nothing here is clever; each step exists because a shortcut
around it has already cost a round.

Three ways in, by what Andy said:

- **"commit"** — Phase 0 and Phase 1, then stop. Say the branch is unpushed.
- **"ship" / "commit and PR" / "open a PR"** — every phase.
- **"merge" / "merge the PR"** — the branch already has a PR: Phase 0, then
  Phase 3's auto-merge line, then Phase 4.

## Ground facts

- Two required checks, both on every PR regardless of what it touches (a
  path-filtered required check never reports and blocks the merge forever):
  **`Build + unit tests (iOS Simulator)`** from `ci.yml`, about 8 minutes, and
  **`web`** from `web-ci.yml`, about 90 seconds, which runs
  `scripts/check-parity-ledger.sh` before anything else. Vercel adds two
  informational checks on web changes.
- Squash merge, auto-merge allowed, **branches are not deleted on merge** —
  that's yours in Phase 5.
- Branch names: `claude/<slug>` for work, `release/<version>` for cuts.
- `.claude/skills/` is tracked (the `.gitignore` negates it); the rest of
  `.claude/` is per-checkout and never goes in a commit.
- Attribution lines come from **the session's own attribution reminder**, not
  from here: commit messages end with its `Co-Authored-By:` line, PR bodies
  with its "Generated with Claude Code" line. The model name in them changes;
  this file doesn't.

## Phase 0 — Where you are

```bash
git status --short --branch
git log --oneline origin/main..HEAD | head -5
gh pr view --json number,url,state,mergeStateStatus,autoMergeRequest 2>/dev/null
```

Read the branch `git status` names. Andy switches branches alongside the
session, so the branch the conversation started on may not be the one
checked out now — a 2026-10-18 commit meant for a feature branch landed on
main this way. Then:

- **On `main`:** never commit there. `git switch -c claude/<slug>` first;
  uncommitted changes come along.
- **Clean tree, branch pushed, open PR:** report its URL and state and stop.
  (If the ask was "merge", carry on to Phase 3's auto-merge line.)
- **Clean tree, no PR:** nothing to commit; skip to Phase 3.
- **Nothing between `origin/main` and `HEAD` and a clean tree:** there is
  nothing to ship. Say so.
- **In a worktree:** the stash is shared with every other session's worktree.
  Never bare `git stash`; park work in a WIP commit instead.

## Phase 1 — Commit everything related

The rule is *all* related uncommitted changes on the current branch: earlier
edits from this session, Andy's own edits, untracked files that belong to the
work. A scoped commit only when he asked for one.

Look before you add — `git status --short` for untracked files, `git diff
--stat` for the rest. Leave out and name anything that isn't the work: build
products, screenshots dropped in the repo root, `.env` files, anything that
looks like a secret.

The message: a subject that reads as a sentence about what changed (a doc or
surface prefix where the repo uses one — `CLAUDE.md: …`, `Web: …`), a body
that gives the *why* in the voice of the decisions log, wrapped near 76
columns, no conventional-commit prefixes, then a blank line and the
`Co-Authored-By:` line. Write it to a file and commit from it so quoting
can't bite:

```bash
git add -A                      # after you've read the status
git commit -F "$SCRATCH/commit-msg.txt"
git show --stat HEAD | head -30 # nothing unintended in the file list
```

If "commit" was the whole ask, stop here: committed `<sha>` on `<branch>`,
not pushed.

## Phase 2 — The decision, in `docs/changes/<pr>.md`

A PR that makes a product, design or architecture decision records it in its
own file under `docs/changes/` and touches neither `docs/decisions.md` nor
`docs/web-parity.md`, which are frozen. `docs/changes/README.md` is the spec.
A test fix, a CI edit or a skill makes no decision and adds no file.

The filename is the PR number, so the file is written **after `gh pr create`**
(Phase 3) and pushed as a second commit — or in the same commit if you already
know the number. The shape:

```markdown
---
pr: 123
date: 2026-10-19
---

## Decision

**Bold headline.** The specifics.

## Why

The reasoning. Required.

## Web parity

n/a — one of shipped / pending / n/a / differs, then a dash and the note.

## Backlog

BACKLOG E29   (optional)
```

Several decisions in one PR repeat the block from `## Decision`. Check it
before pushing, with the same script web CI runs:

```bash
scripts/check-parity-ledger.sh origin/main
```

If the PR ships something `BACKLOG.md` lists, flip the row's checkbox in the
same PR with a note on what shipped and what's still owed. Nothing enforces
this one, which is why it rots.

**Until PR #276 merges** (`git ls-tree origin/main docs/changes/README.md`
prints nothing), `docs/changes/` doesn't exist: append a dated row to both
`docs/decisions.md` and `docs/web-parity.md` instead, expect a conflict with
main on each, and resolve it by merging main and keeping both sides' rows.

## Phase 3 — Push, PR, auto-merge

```bash
git push -u origin HEAD
```

The body follows `.github/pull_request_template.md`, which `gh pr create
--body-file` does *not* apply for you. Open with the argument — what was wrong,
why this is the fix, and what you'd have to believe for it to be the wrong one
— then the three sections, one box ticked in each: **Web parity**, **Backlog
closure**, **Verification** (what you ran and what it said; "tests pass" is
not verification). End with the Generated-with line. Write it to a file.

The title becomes the squash commit's subject on main, forever: a sentence
about the change, no ticket prefix, no PR number.

```bash
gh pr create --base main --title "<sentence>" --body-file "$SCRATCH/pr-body.md"
gh pr merge --auto --squash
gh pr view --json url,autoMergeRequest --jq '"\(.url) auto-merge: \(.autoMergeRequest.enabledAt)"'
```

Auto-merge is the default; skip that line only if Andy said he wants to read
the PR first. A branch stacked on another open PR's branch takes `--base <that
branch>` — and never delete a base branch with a PR still on it; GitHub closes
the PR.

If Phase 2 owes a change file, now you have the number: write it, run the
check, commit (`Record the decision in docs/changes/<pr>.md`), push.

## Phase 4 — Watch CI

**In the Claude desktop app**, the PR bar picks the PR up (`ccd_pr` `get_status`;
`bind_pr` with the URL if it didn't) and the app watches it and wakes the
session on a failure, a conflict or a review comment. Don't poll there.
Anywhere else:

```bash
gh pr checks --watch --fail-fast
```

A push during a run cancels the older run (`cancel-in-progress`); a check that
reads *cancelled* is not a failure. When one does fail:

1. Read it: `gh run view <run-id> --log-failed | tail -80`.
2. **Before fixing a test, check whether main fails the same way:**
   `gh run list --workflow ci.yml --branch main --limit 3 --json conclusion,displayTitle,url`.
   Red on main with the same test is pre-existing — say so with the run URL,
   don't chase it, and tell Andy the merge needs his call, since a red
   required check holds auto-merge. New on this branch is yours: fix, commit,
   push, watch again.
3. **`web` fails on the parity check:** the message names the file and the
   missing field. Fix the change file (pre-cutover, the missing ledger row).
4. **Conflict** (`mergeStateStatus: DIRTY`): `git fetch origin && git merge
   origin/main`, resolve, push. In an app-made worktree, use the host's
   `sync_with_base_branch` tool instead of merging yourself.

## Phase 5 — Report, then tidy

Lead with the PR URL. Then: the checks' state, whether auto-merge is armed,
and anything not verified. Once it has merged (`gh pr view --json state,mergedAt`):

```bash
git push origin --delete <branch>      # the repo doesn't do this for you
```

In a plain checkout, `git switch main && git pull`. In an app worktree, leave
the checkout where it is; the app archives it.
