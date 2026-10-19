#!/usr/bin/env bash
#
# One isolated lane for a UI task: its own worktree, its own simulator,
# its own DerivedData. The parallel-ui skill (.claude/skills/parallel-ui)
# drives this; nothing here knows about the lanes running beside it,
# which is the point.
#
#   scripts/parallel-ui-task.sh up <slug>             worktree on ui/<slug> + a cloned, booted sim
#   scripts/parallel-ui-task.sh build <slug>          build into <wt>/build/DerivedData
#   scripts/parallel-ui-task.sh install <slug>        install + launch on the task's sim only
#   scripts/parallel-ui-task.sh test <slug>           unit tests (sportsTests) on the task's sim
#   scripts/parallel-ui-task.sh shots <slug>          light + dark SurfaceScreenshotTests → PNGs
#   scripts/parallel-ui-task.sh publish-shots <slug>  push PNGs to the ui-screenshots branch, print a table
#   scripts/parallel-ui-task.sh status <slug>         paths and UDID
#   scripts/parallel-ui-task.sh down <slug>           delete the sim, remove the worktree (branch stays)
#
# Environment:
#   BASE=origin/main          what the worktree branches from
#   SIM_SOURCE=<name|udid>    the shut-down simulator to clone (default: a shut-down
#                             iPhone 17 Pro on the newest iOS 26 runtime)
#   SHOT_LEAGUES=cfb,nba,nhl  and SHOT_TEAM_CFB / _NBA / _NHL / _NFL to pick the
#                             team whose game page is shot (see SurfaceScreenshotTests)
#   FORCE=1                   `down` removes a worktree with uncommitted changes
#
# Every device operation takes the UDID written to <wt>/build/sim.udid.
# Nothing here ever says `booted`: other sessions own those devices.

set -euo pipefail

BUNDLE_ID="com.andyryanweir.sports"
SCHEME="sports"
APP_NAME="StatSide.app"
SHOTS_BRANCH="ui-screenshots"

die() { echo "parallel-ui-task: $*" >&2; exit 1; }

cmd="${1:-}"; slug="${2:-}"
[[ -n "$cmd" && -n "$slug" ]] || { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug must be kebab-case: $slug"

# The main checkout, whichever worktree this script was run from.
COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="$(dirname "$COMMON")"
WT="$ROOT/.claude/worktrees/ui-$slug"
BRANCH="ui/$slug"
SIM_NAME="ui-$slug"
BUILD="$WT/build"
DERIVED="$BUILD/DerivedData"
UDID_FILE="$BUILD/sim.udid"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/$APP_NAME"

udid() {
  [[ -f "$UDID_FILE" ]] || die "no simulator recorded for $slug; run: $0 up $slug"
  cat "$UDID_FILE"
}

# "udid<TAB>state<TAB>runtime<TAB>name<TAB>devicetype" for every available iPhone.
list_iphones() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"].startswith("iPhone"):
            rt = runtime.rsplit(".", 1)[-1]
            dt = d.get("deviceTypeIdentifier", "").rsplit(".", 1)[-1]
            print("\t".join([d["udid"], d["state"], rt, d["name"], dt]))'
}

pick_source() {
  if [[ -n "${SIM_SOURCE:-}" ]]; then
    while IFS=$'\t' read -r u state rt name dt; do
      if [[ "$SIM_SOURCE" == "$u" || "$SIM_SOURCE" == "$name" ]]; then
        [[ "$state" == "Shutdown" ]] || die "SIM_SOURCE $name is $state; simctl can only clone a shut-down device"
        echo "$u"; return
      fi
    done < <(list_iphones)
    die "SIM_SOURCE $SIM_SOURCE is not an available iPhone simulator"
  fi
  # Preference: a shut-down iPhone 17 Pro on an iOS 26 runtime, then any
  # shut-down iPhone on iOS 26. The stock 17 Pro is usually booted (and
  # shared), so in practice this finds a sibling clone that was left shut.
  local best=""
  while IFS=$'\t' read -r u state rt name dt; do
    [[ "$state" == "Shutdown" && "$rt" == iOS-26-* ]] || continue
    if [[ "$dt" == "iPhone-17-Pro" ]]; then echo "$u"; return; fi
    [[ -z "$best" ]] && best="$u"
  done < <(list_iphones)
  echo "$best"
}

newest_ios26_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
rts = [r for r in json.load(sys.stdin)["runtimes"]
       if r["isAvailable"] and r["identifier"].rsplit(".", 1)[-1].startswith("iOS-26")]
rts.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
print(rts[-1]["identifier"] if rts else "")'
}

case "$cmd" in
  up)
    base="${BASE:-origin/main}"
    git -C "$ROOT" fetch -q origin
    if [[ -d "$WT" ]]; then
      echo "worktree exists: $WT"
    elif git -C "$ROOT" show-ref --verify -q "refs/heads/$BRANCH"; then
      git -C "$ROOT" worktree add "$WT" "$BRANCH"
    else
      git -C "$ROOT" worktree add -b "$BRANCH" "$WT" "$base"
    fi
    # The capture test has to exist in the tree being built, or step 4 of
    # the skill has nothing to run.
    [[ -f "$WT/sportsUITests/SurfaceScreenshotTests.swift" ]] \
      || die "$base has no sportsUITests/SurfaceScreenshotTests.swift — merge the parallel-ui skill PR first, or pass BASE=<ref> that carries it"
    mkdir -p "$BUILD"

    if [[ -f "$UDID_FILE" ]] && xcrun simctl list devices | grep -q "$(cat "$UDID_FILE")"; then
      echo "simulator exists: $(cat "$UDID_FILE")"
    else
      src="$(pick_source)"
      if [[ -n "$src" ]]; then
        new="$(xcrun simctl clone "$src" "$SIM_NAME")"
        echo "cloned $src -> $new ($SIM_NAME)"
      else
        rt="$(newest_ios26_runtime)"
        [[ -n "$rt" ]] || die "no iOS 26 runtime installed"
        new="$(xcrun simctl create "$SIM_NAME" "iPhone 17 Pro" "$rt")"
        echo "no shut-down iPhone to clone; created $new ($SIM_NAME) fresh on $rt"
      fi
      echo "$new" > "$UDID_FILE"
    fi
    u="$(udid)"
    xcrun simctl boot "$u" 2>/dev/null || true
    xcrun simctl bootstatus "$u" -b >/dev/null
    # The defaults every suite assumes (CLAUDE.md § Running the UI tests).
    xcrun simctl ui "$u" content_size large >/dev/null 2>&1 || true
    xcrun simctl ui "$u" appearance light >/dev/null 2>&1 || true
    echo "worktree  $WT"
    echo "branch    $BRANCH"
    echo "simulator $SIM_NAME"
    echo "udid      $u"
    ;;

  build)
    u="$(udid)"; mkdir -p "$BUILD"
    echo "Building $BRANCH for $SIM_NAME ($u)…"
    if ! xcodebuild -project "$WT/sports.xcodeproj" -scheme "$SCHEME" \
        -destination "id=$u" -derivedDataPath "$DERIVED" build >"$BUILD/build.log" 2>&1; then
      grep -E "error:" "$BUILD/build.log" >&2 || tail -30 "$BUILD/build.log" >&2
      die "build failed; log at $BUILD/build.log"
    fi
    echo "built $APP"
    ;;

  install)
    u="$(udid)"
    [[ -d "$APP" ]] || die "no app at $APP; run: $0 build $slug"
    xcrun simctl terminate "$u" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$u" "$APP"
    xcrun simctl launch "$u" "$BUNDLE_ID" >/dev/null
    container="$(xcrun simctl get_app_container "$u" "$BUNDLE_ID" app)"
    echo "installed $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$container/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$container/Info.plist")) on $SIM_NAME ($u)"
    ;;

  test)
    u="$(udid)"; mkdir -p "$BUILD"
    [[ -d "$BUILD/unit.xcresult" ]] && rm -rf "${BUILD:?}/unit.xcresult"
    echo "Unit tests on $SIM_NAME ($u)…"
    set +e
    xcodebuild test -project "$WT/sports.xcodeproj" -scheme "$SCHEME" \
      -destination "id=$u" -derivedDataPath "$DERIVED" \
      -only-testing:sportsTests -parallel-testing-enabled NO \
      -resultBundlePath "$BUILD/unit.xcresult" >"$BUILD/unit-tests.log" 2>&1
    status=$?
    set -e
    grep -E "Test Suite '(sportsTests|All tests)'|Executed [0-9]+ tests" "$BUILD/unit-tests.log" | tail -4 || true
    grep -E "error:|failed \(" "$BUILD/unit-tests.log" | grep -v "^Test Suite" | head -20 || true
    [[ $status -eq 0 ]] && echo "unit tests passed" || die "unit tests failed (exit $status); log at $BUILD/unit-tests.log"
    ;;

  shots)
    u="$(udid)"
    for mode in light dark; do
      for stale in "shots-$mode.xcresult" "shots/raw-$mode" "shots/$mode"; do
        [[ -e "$BUILD/$stale" ]] && rm -rf "${BUILD:?}/${stale:?}"
      done
      mkdir -p "$BUILD/shots/$mode"
      xcrun simctl ui "$u" appearance "$mode"
      echo "Shooting $mode on $SIM_NAME ($u)…"
      # TEST_RUNNER_ env reaches the test process with the prefix stripped.
      # The suite attaches what it can and logs what it couldn't, so the
      # result is read from the PNG count, not the exit status.
      TEST_RUNNER_SNAPSHOT_PREFIX="$mode" \
      TEST_RUNNER_SHOT_LEAGUES="${SHOT_LEAGUES:-cfb,nba,nhl}" \
      TEST_RUNNER_SHOT_TEAM_CFB="${SHOT_TEAM_CFB:-}" TEST_RUNNER_SHOT_TEAM_NFL="${SHOT_TEAM_NFL:-}" \
      TEST_RUNNER_SHOT_TEAM_NBA="${SHOT_TEAM_NBA:-}" TEST_RUNNER_SHOT_TEAM_NHL="${SHOT_TEAM_NHL:-}" \
      xcodebuild test -project "$WT/sports.xcodeproj" -scheme "$SCHEME" \
        -destination "id=$u" -derivedDataPath "$DERIVED" \
        -only-testing:sportsUITests/SurfaceScreenshotTests -parallel-testing-enabled NO \
        -resultBundlePath "$BUILD/shots-$mode.xcresult" >"$BUILD/shots-$mode.log" 2>&1 || true
      [[ -d "$BUILD/shots-$mode.xcresult" ]] || die "no result bundle for $mode; log at $BUILD/shots-$mode.log"
      xcrun xcresulttool export attachments --path "$BUILD/shots-$mode.xcresult" \
        --output-path "$BUILD/shots/raw-$mode" >/dev/null
      python3 - "$BUILD/shots/raw-$mode" "$BUILD/shots/$mode" <<'PY'
import json, os, re, shutil, sys
raw, out = sys.argv[1], sys.argv[2]
for test in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        # "light-scores_0_7B3854CA-….png": the attachment name, then Xcode's
        # repetition counter and a UUID. Keep the name.
        name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", os.path.splitext(name)[0]) + ".png"
        shutil.copy(os.path.join(raw, a["exportedFileName"]), os.path.join(out, name))
PY
      grep -E "MISSING SURFACE" "$BUILD/shots-$mode.log" || true
      echo "$mode: $(ls "$BUILD/shots/$mode" | wc -l | tr -d ' ') shots in $BUILD/shots/$mode"
    done
    xcrun simctl ui "$u" appearance light
    ;;

  publish-shots)
    ls "$BUILD"/shots/light/*.png >/dev/null 2>&1 || die "no shots to publish; run: $0 shots $slug"
    repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
    tmp="$(mktemp -d)"
    git -C "$ROOT" fetch -q origin
    if git -C "$ROOT" show-ref --verify -q "refs/remotes/origin/$SHOTS_BRANCH"; then
      git -C "$ROOT" worktree add -q --detach "$tmp" "origin/$SHOTS_BRANCH"
    else
      # First ever publish: an orphan with nothing but a README, so the
      # branch never shares history with main and can't be merged into it
      # by accident.
      git -C "$ROOT" worktree add -q --orphan -b "$SHOTS_BRANCH" "$tmp"
      printf '# UI screenshots\n\nPNGs the parallel-ui skill embeds in PR bodies, one directory per task slug.\nNever merged anywhere; linked by commit SHA.\n' > "$tmp/README.md"
      git -C "$tmp" add README.md
      git -C "$tmp" commit -qm "Seed the screenshots branch"
    fi
    [[ -d "$tmp/$slug" ]] && rm -rf "${tmp:?}/${slug:?}"
    mkdir -p "$tmp/$slug"
    for mode in light dark; do
      for f in "$BUILD"/shots/$mode/*.png; do
        [[ -f "$f" ]] && cp "$f" "$tmp/$slug/$(basename "$f")"
      done
    done
    git -C "$tmp" add "$slug"
    git -C "$tmp" commit -qm "Screenshots for $BRANCH" || true
    for attempt in 1 2 3 4 5; do
      if git -C "$tmp" push -q origin "HEAD:refs/heads/$SHOTS_BRANCH" 2>/dev/null; then break; fi
      [[ $attempt -lt 5 ]] || die "could not push to $SHOTS_BRANCH after 5 attempts"
      git -C "$tmp" fetch -q origin "$SHOTS_BRANCH"
      git -C "$tmp" rebase -q "origin/$SHOTS_BRANCH" || die "rebase onto $SHOTS_BRANCH failed in $tmp"
    done
    sha="$(git -C "$tmp" rev-parse HEAD)"
    git -C "$ROOT" worktree remove --force "$tmp"

    base_url="https://raw.githubusercontent.com/$repo/$sha/$slug"
    table="$BUILD/shots/table.md"
    {
      echo "| Surface | Light | Dark |"
      echo "|---|---|---|"
      for f in "$BUILD"/shots/light/light-*.png; do
        [[ -f "$f" ]] || continue
        name="$(basename "$f" .png)"; name="${name#light-}"
        darkcell="—"
        [[ -f "$BUILD/shots/dark/dark-$name.png" ]] && darkcell="<img src=\"$base_url/dark-$name.png\" width=\"220\">"
        echo "| $name | <img src=\"$base_url/light-$name.png\" width=\"220\"> | $darkcell |"
      done
    } > "$table"
    echo "published to $SHOTS_BRANCH @ ${sha:0:7}; table at $table"
    cat "$table"
    ;;

  status)
    echo "worktree  $WT $([[ -d "$WT" ]] && echo '(present)' || echo '(missing)')"
    echo "branch    $BRANCH"
    echo "simulator $SIM_NAME"
    if [[ -f "$UDID_FILE" ]]; then
      u="$(cat "$UDID_FILE")"
      state="$(xcrun simctl list devices | grep "$u" | sed -E 's/.*\(([A-Za-z]+)\) *$/\1/')"
      echo "udid      $u (${state:-gone})"
    else
      echo "udid      (none)"
    fi
    ;;

  down)
    if [[ -f "$UDID_FILE" ]]; then
      u="$(cat "$UDID_FILE")"
      xcrun simctl shutdown "$u" 2>/dev/null || true
      if xcrun simctl delete "$u" 2>/dev/null; then
        echo "deleted simulator $SIM_NAME ($u)"
      else
        echo "simulator $u already gone"
      fi
    fi
    if [[ -d "$WT" ]]; then
      if [[ -n "$(git -C "$WT" status --porcelain)" && "${FORCE:-0}" != "1" ]]; then
        die "$WT has uncommitted changes; commit them or pass FORCE=1"
      fi
      git -C "$ROOT" worktree remove --force "$WT"
      echo "removed worktree $WT (branch $BRANCH kept)"
    fi
    ;;

  *) die "unknown command: $cmd" ;;
esac
