#!/usr/bin/env bash
#
# Run — or re-record — the component snapshot baselines
# (sportsTests/Snapshots/ComponentSnapshotTests.swift).
#
#   scripts/snapshot-tests.sh                       compare every snapshot to its baseline
#   scripts/snapshot-tests.sh --record              re-record every baseline
#   scripts/snapshot-tests.sh --record --filter gameHeaderCompact
#                                                   re-record one component (a test name;
#                                                   several comma-separated)
#   scripts/snapshot-tests.sh --filter dayStrip     compare one component
#
# The baselines are pixels from one runtime: the iOS 26.5 iPhone 17 Pro
# simulator. This runs on a simulator of its own, "iPhone 17 Pro snapshot-tests",
# created here if it is missing, so another session's install on the shared
# devices can't change what the host app is (CLAUDE.md § Simulator workflow).
# The suite is gated on STATSIDE_SNAPSHOTS=1 so CI, on whatever runner it
# gets, skips it; this script sets it (as TEST_RUNNER_STATSIDE_SNAPSHOTS in
# xcodebuild's environment, which is how a variable reaches the test host).
#
# Exit status is xcodebuild's: non-zero when a snapshot differs from its
# baseline. The failed images (reference / failure / difference) are in the
# result bundle this prints, and `scripts/ui-report.py` turns the working
# tree's changed PNGs into a side-by-side page.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_NAME="iPhone 17 Pro snapshot-tests"
SIM_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
SIM_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
DERIVED="${TMPDIR:-/tmp}/statside-snapshots"
SUITE="sportsTests/ComponentSnapshotTests"

record=0
filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --record) record=1 ;;
    --filter) filter="$2"; shift ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# The dedicated simulator, by name on the pinned runtime; made if missing.
udid="$(xcrun simctl list devices -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
print(next((d["udid"] for d in devices if d["name"] == name and d["isAvailable"]), ""))
' "$SIM_NAME" "$SIM_RUNTIME")"
if [[ -z "$udid" ]]; then
  echo "Creating simulator \"$SIM_NAME\" (iPhone 17 Pro, iOS 26.5)…"
  udid="$(xcrun simctl create "$SIM_NAME" "$SIM_TYPE" "$SIM_RUNTIME")"
fi
if ! xcrun simctl list devices booted | grep -q "$udid"; then
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
fi
# The size and appearance the baselines assume; the tests pin both in
# their traits too, so this is belt and braces.
xcrun simctl ui "$udid" content_size large >/dev/null 2>&1 || true
xcrun simctl ui "$udid" appearance light >/dev/null 2>&1 || true

only="$SUITE"

stamp="$(date +%Y%m%d-%H%M%S)"
bundle="$DERIVED/results-$stamp.xcresult"
mkdir -p "$DERIVED"

args=(
  test
  -project "$ROOT/sports.xcodeproj"
  -scheme sports
  -destination "id=$udid"
  -only-testing:"$only"
  -parallel-testing-enabled NO
  -derivedDataPath "$DERIVED"
  -resultBundlePath "$bundle"
)
# Environment, not build settings: a `KEY=VALUE` argument to xcodebuild is a
# build setting, which the test host never sees. `TEST_RUNNER_` variables in
# xcodebuild's own environment reach the host with the prefix stripped.
export TEST_RUNNER_STATSIDE_SNAPSHOTS=1
# One component: the suite's own filter. `-only-testing` selects the suite
# but matches none of its parameterized functions (Xcode 26.6), so the
# tests read this and the rest skip themselves.
[[ -n "$filter" ]] && export TEST_RUNNER_STATSIDE_SNAPSHOT_FILTER="${filter%%(*}"
if [[ $record -eq 1 ]]; then
  export TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all
  echo "Recording ${filter:-every} baseline on $SIM_NAME ($udid)…"
else
  echo "Comparing ${filter:-every} snapshot on $SIM_NAME ($udid)…"
fi

log="$DERIVED/xcodebuild-$stamp.log"
status=0
xcodebuild "${args[@]}" >"$log" 2>&1 || status=$?

# The lines worth reading, whatever happened.
grep -E "error:|Test Suite .* (passed|failed)|Executed [0-9]+ tests|◇ Test .* (passed|failed|recorded)|✘|Snapshot .* recorded|Record mode is on" "$log" \
  | grep -vE "^\s*$" | sort -u | head -80 || true

if [[ $status -ne 0 ]]; then
  echo
  if [[ $record -eq 1 ]]; then
    # Record mode fails every test by design (it wrote, it didn't compare).
    if grep -q "Record mode is on" "$log" || grep -q "recorded" "$log"; then
      echo "Recorded. Review the PNGs under sportsTests/Snapshots/__Snapshots__/ before committing."
      exit 0
    fi
  fi
  echo "xcodebuild exited $status — log: $log"
  echo "result bundle: $bundle"
  exit $status
fi
# A selection that matched nothing passes xcodebuild and proves nothing.
if grep -qE "Test run with 0 tests" "$log"; then
  echo
  echo "No test matched ${filter:-$only} — nothing was compared. Log: $log"
  exit 3
fi
echo
echo "All snapshots match. Result bundle: $bundle"
