#!/usr/bin/env bash
#
# Put the working tree on the dedicated simulator and screenshot it.
#
#   scripts/verify-sim.sh                  build, install, launch, screenshot → /tmp/ui-report/sim-scores.png
#   scripts/verify-sim.sh --name roster    …→ /tmp/ui-report/sim-roster.png
#   scripts/verify-sim.sh --shot-only      skip the build; screenshot what is running now
#   scripts/verify-sim.sh --dark           flip the simulator dark first (--light flips back)
#
# The device is "iPhone 17 Pro snapshot-tests", the same iPhone 17 Pro (iOS 26.5)
# the baselines are recorded on, so what this shows is the build the
# snapshots describe and no other session's. Deeper screens than the launch
# screen are reached by tapping — the iOS Simulator tool in the session can
# tap and screenshot the same device by name — and then `--shot-only` names
# the picture; `scripts/ui-report.py --sim <png>` puts it on the report page.
#
# The build goes through scripts/install-all-sims.sh with this device's
# UDID, so it is the same `xcodebuild` and the same install everything else
# uses.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_NAME="iPhone 17 Pro snapshot-tests"
SIM_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
SIM_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
BUNDLE_ID="com.andyryanweir.sports"
OUT_DIR="/tmp/ui-report"

name="scores"
build=1
appearance=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="$2"; shift ;;
    --shot-only) build=0 ;;
    --dark) appearance="dark" ;;
    --light) appearance="light" ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

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
xcrun simctl ui "$udid" content_size large >/dev/null 2>&1 || true
[[ -n "$appearance" ]] && xcrun simctl ui "$udid" appearance "$appearance" >/dev/null 2>&1

if [[ $build -eq 1 ]]; then
  "$ROOT/scripts/install-all-sims.sh" "$udid"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" -ui.scoreFilter none >/dev/null
  # Let the first slate land before the picture.
  sleep 4
fi

mkdir -p "$OUT_DIR"
shot="$OUT_DIR/sim-$name.png"
xcrun simctl io "$udid" screenshot "$shot" >/dev/null
echo "$shot"
