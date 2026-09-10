<!--
  The body is the argument, not the changelog: what was wrong, why this is
  the fix, and what you'd have to believe for it to be the wrong one.
-->

## Web parity

`web/` and the iOS app are two implementations of one product. The
2026-09-01 port had nothing holding it and decayed to 1.x in eight days —
89 iOS decision rows, one of which reached the web.

So: **if this PR adds a row to `CLAUDE.md`'s decisions log, it adds one to
`docs/web-parity.md` too.** One of these is true —

- [ ] No new decision rows — nothing to mirror.
- [ ] Ledger updated: every new decision has a row with a status.
- [ ] Skip token on a line of its own in a commit message — genuinely no
      product surface (a test harness, a build setting), not a deferred row.

`shipped` / `pending` / `n/a` / `differs`. **`n/a` is a complete answer** and
takes one line: a widget, a haptic, an XCUITest fixture has no web analog,
and saying so closes the row for good. `pending` is the honest status for
"real, not done yet" — the point is that it is *counted*, not that it is
zero.

Both are automated: `scripts/check-parity-ledger.sh` fails the web job if
the ledger didn't grow, and `scripts/parity-status.sh` prints where parity
stands on every PR.

## Verification

<!--
  What you actually ran and what it said. "Tests pass" is not verification;
  "the SEC page folds 16 earlier games behind Week 2" is.
-->
