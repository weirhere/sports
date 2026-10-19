#!/usr/bin/env bash
#
# Claude Code Stop hook: keep the simulator current.
#
# Runs at the end of every Claude turn. If any Swift file is modified,
# staged or untracked in this checkout, builds once and installs on every
# booted iPhone simulator via install-all-sims.sh, so what Andy looks at is
# never a stale build. A clean tree, or a turn that touched no Swift, costs
# one `git status` and exits.
#
#   STATSIDE_SIM=<name or udid>   install only to that device (a session
#                                 that cloned its own simulator sets this)
#   FORCE=1                       build and install even with a clean tree
#
# Output goes to $TMPDIR/statside-stop-install.log, not the transcript.
# A lock directory stops two sessions' hooks building into the same
# DerivedData at once; the second one logs "skipped" and exits 0.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG="${TMPDIR:-/tmp}/statside-stop-install.log"
LOCK="${TMPDIR:-/tmp}/statside-stop-install.lock"

if [[ "${FORCE:-0}" != "1" ]]; then
  git status --porcelain -- '*.swift' | grep -q . || exit 0
fi

if ! mkdir "$LOCK" 2>/dev/null; then
  echo "== $(date '+%F %T') $ROOT: another install is running, skipped" >> "$LOG"
  exit 0
fi
trap 'rmdir "$LOCK"' EXIT

{
  echo "== $(date '+%F %T') $ROOT ${STATSIDE_SIM:+-> $STATSIDE_SIM}"
  scripts/install-all-sims.sh ${STATSIDE_SIM:+"$STATSIDE_SIM"}
  echo "== exit $?"
} >> "$LOG" 2>&1
