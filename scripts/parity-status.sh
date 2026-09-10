#!/usr/bin/env bash
#
# Where web parity actually stands, counted rather than felt.
#
# The ledger's whole promise is that parity is *measurable* rather than
# aspirational — but a 400-line document only delivers that if someone can
# ask it a question. This is the question: how many decisions are shipped,
# how many are pending, how many have no web analog at all.
#
# Run it any time (`./scripts/parity-status.sh`); the web CI job prints it
# on every PR, where it costs nothing and makes drift visible while it is
# still one row instead of eighty-nine.
#
# Informational by design — it never fails a build. `check-parity-ledger.sh`
# is the thing with teeth; this is the thing with the number.

set -euo pipefail

LEDGER_FILE="${1:-docs/web-parity.md}"

if [ ! -f "$LEDGER_FILE" ]; then
  echo "No ledger at $LEDGER_FILE"
  exit 0
fi

# A row is a table line whose first cell is a date (or an em dash). The
# status is its **last** cell — "shipped — W4b", "pending — W5b", "n/a".
# Matched by keyword rather than exact string, because a status carries its
# wave and often a clause explaining itself.
python3 - "$LEDGER_FILE" <<'PY'
import re, sys
from collections import Counter

path = sys.argv[1]
row = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2}[^|]*|—)\s*\|(.+)\|\s*$")
counts = Counter()
in_na_section = False

for line in open(path, encoding="utf-8"):
    stripped = line.strip()
    if stripped.startswith("## "):
        # The n/a section's last column is a reason, not a status — its rows
        # are all n/a by virtue of the heading they sit under.
        in_na_section = "n/a" in stripped
        continue
    match = row.match(stripped)
    if not match:
        continue
    if in_na_section:
        counts["n/a"] += 1
        continue
    cells = [cell.strip() for cell in match.group(2).split("|")]
    status = cells[-1].lower() if cells else ""
    for key in ("shipped", "pending", "differs", "n/a"):
        if key in status:
            counts[key] += 1
            break
    else:
        counts["unlabelled"] += 1

total = sum(counts.values())
if total == 0:
    print("No ledger rows found.")
    sys.exit(0)

print(f"Web parity — {total} decisions tracked")
for key in ("shipped", "pending", "differs", "n/a", "unlabelled"):
    n = counts.get(key, 0)
    if n == 0:
        continue
    print(f"  {key:<11} {n:>4}  ({n * 100 // total}%)")

pending = counts.get("pending", 0)
if pending == 0:
    print("\nNothing pending — the web is level with the decisions log.")
else:
    print(f"\n{pending} decision(s) not yet answered on the web.")
PY
