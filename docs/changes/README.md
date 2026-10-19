# docs/changes — one file per PR

This directory replaced the tail of `docs/decisions.md` and `docs/web-parity.md`
on 2026-10-19. Those two files are frozen history now. **Every PR that makes a
product, design or architecture decision adds one file here and touches
nothing shared.**

## Why

Both ledgers were append-only tables, and every PR wrote the last line of
each. Two branches that each add a trailing row conflict by construction, on
the same line, every time one lands before the other. Measured the day of the
cutover: of the 80 most recently merged PRs, 72 touched a ledger, and 31 had
another ledger PR merge while they were open. Each of those was a hand-resolved
conflict for a row nobody disagreed about.

Two files from two PRs cannot conflict. The readable tables are built from the
files instead of edited by hand.

## The file

`docs/changes/<pr-number>.md`, or `<pr-number>-<slug>.md` if you like a name.
Open the PR first (`gh pr create`) to get the number — or write the file last.

```markdown
---
pr: 276
date: 2026-10-19
---

## Decision

**The Roster tab reaches the web.** `web/src/lib/game-roster.ts` is a
line-for-line twin of `GameRoster`; the route serves the three sources and
the client assembles the lists against the summary it already polls.

## Why

Client-side assembly was the cheaper shape *and* the better one: the web's
game page already holds a live summary, so re-fetching six endpoints to learn
what it already knew would have been iOS's cost without iOS's reason.

## Web parity

differs — the lists are the same; they refresh with the poll on web.

## Backlog

BACKLOG E29
```

- `## Decision` — what changed, in the voice of the log: a bold headline,
  then the specifics. This is the row's second column.
- `## Why` — the reasoning. Required. A row that says what changed and not
  why is what the log exists to prevent.
- `## Web parity` — required. Starts with one of `shipped`, `pending`, `n/a`,
  `differs`, then a dash and the note. `n/a` is a complete answer and takes one
  line. `pending` is the honest status for "real, not done yet".
- `## Backlog` — optional. The log's fourth column (`BACKLOG E29`).

A PR with several decisions repeats the block: each `## Decision` starts a new
entry and the sections after it belong to that entry, until the next one.

## Reading the log

`scripts/build-changelog.py build` writes `docs/generated/decisions.md` and
`docs/generated/web-parity.md` — the frozen file with every change-file row
appended, sorted by date then PR — and `docs/generated/` is gitignored, so the
assembled tables are never a thing two PRs edit. Web CI builds them on every
run and uploads them as the `changelog` artifact.

The cheap way in is still cheap: `tail -40 docs/decisions.md` for the history,
`ls -t docs/changes | head` for what landed since.

## Enforced

`scripts/check-parity-ledger.sh` (which web CI runs first) now calls
`build-changelog.py check`: every file here must parse with a date, a decision,
a reason and a parity status, and the branch must not add rows to either frozen
file. There is no skip token any more — the parity line is one word, `n/a` is
allowed, and a PR with no decision just adds no file.
