<!--
  The body is the argument, not the changelog: what was wrong, why this is
  the fix, and what you'd have to believe for it to be the wrong one.
-->

## Web parity

`web/` and the iOS app are two implementations of one product. The
2026-09-01 port had nothing holding it and decayed to 1.x in eight days —
89 iOS decision rows, one of which reached the web.

So: **if this PR makes a decision, it adds `docs/changes/<this PR's number>.md`**
with a `## Decision`, a `## Why` and a `## Web parity` status — and touches
neither `docs/decisions.md` nor `docs/web-parity.md`, which are frozen. One of
these is true —

- [ ] No decision — no change file, nothing to mirror.
- [ ] `docs/changes/<pr>.md` added, every decision in it with a parity status.

`shipped` / `pending` / `n/a` / `differs`. **`n/a` is a complete answer** and
takes one line: a widget, a haptic, an XCUITest fixture has no web analog,
and saying so closes the row for good. `pending` is the honest status for
"real, not done yet" — the point is that it is *counted*, not that it is
zero.

Both are automated: `scripts/check-parity-ledger.sh` fails the web job if a
change file is malformed or a frozen ledger grew, and `scripts/parity-status.sh`
prints where parity stands on every PR.

## Backlog closure

Nothing enforces this one, which is why it rots. The 2026-09-21
reconciliation pass found four shipped features still sitting open in
`BACKLOG.md` — one of which a later session came within a file of
rebuilding, because it read the row and believed it.

So: **if this PR ships something the backlog lists, flip its checkbox in
the same PR**, and append the parenthetical saying what the row didn't
know. A row that is right about the code is the only reason the list is
worth walking.

- [ ] Nothing here is on the backlog, or its row is already closed.
- [ ] Row flipped to `[x]`, with a note on what shipped and what's still owed.
- [ ] Row stays open on purpose — partial work, and the note says which half.

A row whose *premise* has gone false counts too: correct it rather than
leaving a true-sounding sentence about code that changed underneath it.

## Verification

<!--
  What you actually ran and what it said. "Tests pass" is not verification;
  "the SEC page folds 16 earlier games behind Week 2" is.
-->
