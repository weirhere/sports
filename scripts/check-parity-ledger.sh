#!/usr/bin/env bash
#
# The web-parity coupling, enforced.
#
# `web/` and the iOS app are two implementations of one product, and nothing
# in the build couples them. The 2026-09-01 parity port had nothing holding
# it and decayed to 1.x in eight days — 89 iOS decision rows, one of which
# reached the web. This check is the coupling: a PR that adds a row to
# CLAUDE.md's decisions log must also add one to docs/web-parity.md.
#
# It is deliberately dumb. It counts rows, not meaning — it cannot tell
# whether the row you added is the right one, only that you stopped and
# wrote one. `n/a` is a first-class status in the ledger precisely so this
# never forces busywork: a decision with no web analog is recorded as
# having none, in one line, and the check is satisfied.
#
# Escape hatch: put the skip token on a line **of its own** in a commit
# message. Use it for iOS work with genuinely no product surface (a test
# harness, a build setting) — not to defer a real row.
#
# On its own line, and not merely somewhere in the message, because the
# token is a thing people write *about*: this file quotes it, the PR
# template quotes it, and the commit that added them quoted it too — which
# silently disabled the check on the very branch that built it. An
# enforcement mechanism a passing mention can switch off is not one.

set -euo pipefail

BASE_REF="${1:-origin/main}"
CLAUDE_FILE="CLAUDE.md"
LEDGER_FILE="docs/web-parity.md"

# Rows in CLAUDE.md's decisions log are table lines opening with a date.
decision_rows() {
  git show "$1:$CLAUDE_FILE" 2>/dev/null | grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' || true
}

# Rows in the ledger are table lines too. The date cell is looser than
# CLAUDE.md's on purpose: an `n/a` row often covers several decisions at once
# ("| 2026-09-06, 2026-09-07 | every widget decision |"), and a row that
# records two things must not fail the check for doing the right thing. A
# dateless `| — |` counts too.
ledger_rows() {
  git show "$1:$LEDGER_FILE" 2>/dev/null \
    | grep -cE '^\| ([0-9]{4}-[0-9]{2}-[0-9]{2}|—)[^|]*\|' || true
}

SKIP_TOKEN='[skip-parity]'
if git log "$BASE_REF..HEAD" --format='%B' 2>/dev/null \
  | grep -qxF "$SKIP_TOKEN"; then
  echo "✓ $SKIP_TOKEN on its own line — ledger check skipped."
  exit 0
fi

before_decisions=$(decision_rows "$BASE_REF")
after_decisions=$(decision_rows HEAD)
before_ledger=$(ledger_rows "$BASE_REF")
after_ledger=$(ledger_rows HEAD)

added_decisions=$((after_decisions - before_decisions))
added_ledger=$((after_ledger - before_ledger))

echo "decisions log: $before_decisions → $after_decisions  (+$added_decisions)"
echo "parity ledger: $before_ledger → $after_ledger  (+$added_ledger)"

if [ "$added_decisions" -le 0 ]; then
  echo "✓ No new decisions on this branch — nothing to mirror."
  exit 0
fi

if [ "$added_ledger" -ge "$added_decisions" ]; then
  echo "✓ $added_ledger ledger row(s) for $added_decisions new decision(s)."
  exit 0
fi

cat <<EOF

✗ This branch adds $added_decisions decision row(s) to $CLAUDE_FILE but only
  $added_ledger row(s) to $LEDGER_FILE.

  Every decision that changes user-visible behavior needs a line in the
  parity ledger saying where the web stands on it. Add one row per new
  decision, with a status:

    | 2026-09-09 | <the decision, in a phrase> | pending |

  Statuses: shipped / pending / n/a / differs. A decision with no web
  analog — a widget, a haptic, an XCUITest fixture — is \`n/a\`, and that
  is a complete answer; it takes one line and closes the row for good.

  If this branch genuinely has no product surface, put the skip token on a
  line of its own in a commit message — see the header of this script.
EOF
exit 1
