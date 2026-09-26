#!/usr/bin/env bash
#
# One build, every iPhone simulator.
#
# Xcode installs a build on the one simulator you ran it on and nowhere else,
# so the others keep whatever they last got. On 2026-09-26 the iPhone 18 Pro
# was still running 2.3.0 (17) five days and three releases after the 16 Pro
# and 17 Pro had moved to 2.6.0 (20). It looked like the 18 Pro had a
# different app. It had an old one.
#
# This builds the working tree once and installs that one .app everywhere,
# then prints the version each device ended up with, so a device that is
# behind can be spotted from here without opening it.
#
#   scripts/install-all-sims.sh                  every booted iPhone
#   scripts/install-all-sims.sh --all            every available iPhone
#   scripts/install-all-sims.sh "iPhone 18 Pro Max" <udid> ...
#
# A device that was shut down is booted for the install and shut down again
# afterwards. The app is relaunched only where it was already running, and
# installing over the old copy keeps follows and settings.
#
# Simulators here are shared with other sessions and other worktrees, which
# install their own builds on them. Whatever this prints is true until the
# next install from anywhere else.

set -euo pipefail

BUNDLE_ID="com.andyryanweir.sports"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${TMPDIR:-/tmp}/statside-all-sims"

mode="booted"
targets=()
for arg in "$@"; do
  case "$arg" in
    --all) mode="all" ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) mode="named"; targets+=("$arg") ;;
  esac
done

# "udid<TAB>state<TAB>runtime<TAB>name" for every available iPhone simulator.
list_iphones() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"].startswith("iPhone"):
            rt = runtime.rsplit(".", 1)[-1]
            print("\t".join([d["udid"], d["state"], rt, d["name"]]))'
}

devices=()
while IFS= read -r line; do
  IFS=$'\t' read -r udid state _ name <<<"$line"
  case "$mode" in
    booted) [[ "$state" == "Booted" ]] && devices+=("$line") ;;
    all) devices+=("$line") ;;
    named)
      for t in "${targets[@]}"; do
        # UDIDs are unique; a name can exist on several runtimes and matches all of them.
        if [[ "$t" == "$udid" || "$t" == "$name" ]]; then devices+=("$line"); fi
      done ;;
  esac
done < <(list_iphones)

if [[ ${#devices[@]} -eq 0 ]]; then
  echo "No matching iPhone simulators." >&2
  exit 1
fi

commit="$(git -C "$ROOT" rev-parse --short HEAD)"
[[ -n "$(git -C "$ROOT" status --porcelain)" ]] && commit="$commit+dirty"
echo "Building $commit for iOS Simulator…"
mkdir -p "$DERIVED"
if ! xcodebuild -project "$ROOT/sports.xcodeproj" -scheme sports \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" build >"$DERIVED/build.log" 2>&1; then
  grep -E "error:" "$DERIVED/build.log" >&2 || tail -30 "$DERIVED/build.log" >&2
  echo "Build failed; full log at $DERIVED/build.log" >&2
  exit 1
fi

APP="$DERIVED/Build/Products/Debug-iphonesimulator/StatSide.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Info.plist"))"
echo "Built StatSide $version"
echo

failed=0
for line in "${devices[@]}"; do
  IFS=$'\t' read -r udid state runtime name <<<"$line"
  label="$name [$runtime]"

  booted_here=0
  if [[ "$state" != "Booted" ]]; then
    if ! xcrun simctl boot "$udid" 2>/dev/null; then
      printf '  %-40s could not boot, skipped\n' "$label"
      failed=1; continue
    fi
    booted_here=1
  fi

  was_running=0
  if xcrun simctl spawn "$udid" launchctl list 2>/dev/null | grep -q "UIKitApplication:$BUNDLE_ID"; then
    was_running=1
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  fi

  if xcrun simctl install "$udid" "$APP"; then
    [[ $was_running -eq 1 ]] && xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
    container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" app)"
    installed="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$container/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$container/Info.plist"))"
    printf '  %-40s %s%s\n' "$label" "$installed" "$([[ $was_running -eq 1 ]] && echo ', relaunched')"
  else
    printf '  %-40s install failed\n' "$label"
    failed=1
  fi

  [[ $booted_here -eq 1 ]] && xcrun simctl shutdown "$udid" 2>/dev/null || true
done

exit $failed
