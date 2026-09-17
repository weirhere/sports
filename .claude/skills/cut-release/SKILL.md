---
name: cut-release
description: Cut a StatSide App Store release — version bump, listing audit, scoped test run, archive, verify, hand off to App Store Connect. Use when Andy says cut/ship a release, bump the version, submit to the App Store, prep a build for review, or names a version like "let's do 2.3".
---

# Cutting a StatSide release

There is no fastlane, no release CI, no script. A cut is manual `xcodebuild`
plus Xcode Organizer, and almost every step below exists because a release
already failed on it. Work the phases in order; each one ends with a check you
can actually run.

**Andy owns App Store Connect.** Your job ends at a verified archive plus the
copy that goes with it, unless he explicitly asks you to upload. See Phase 6.

## Ground facts

- App: `StatSide`, bundle `com.andyryanweir.sports`, Apple ID **6793266645**,
  team **8XZZYVAD42**. ASC name "StatSide – College Football".
- Two shipping targets that must move together: the app and
  **StatSideWidgets** (the appex). Mismatched versions = rejected upload.
- Deployment target **18.0**, built with the current Xcode/iOS SDK.
- Manual release is the setting. Approval does **not** publish.
- Store copy lives in `docs/appstore/listing.md`. It is the source of truth for
  every ASC field, and it carries the release-notes history.
- Long-lived state (what's live, what's in review, what shipped in each build)
  is in the `statside-app-store-status` memory. Read it first; update it last.

## Phase 0 — Establish where you are

```bash
git -C . status --short && git log --oneline -1
grep -m1 -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION' sports.xcodeproj/project.pbxproj
```

Find the last bump **by the version string, not by the subject line** — read
the current `MARKETING_VERSION` above, then ask git which commit introduced it:

```bash
LAST=$(git log --format=%h -1 -S'MARKETING_VERSION = 2.2.0;' -- sports.xcodeproj/project.pbxproj)
git log --oneline "$LAST"..HEAD | wc -l
```

The `--grep='Cut \|Bump version'` form this used to carry is wrong, and it
fails in the direction that costs you the release: at the 2.3.0 cut it matched
*this skill's own commit* ("Make the release **cut** a skill") and reported **0
commits since the last bump** on a branch with 34. A grep over subject lines
answers "what was worded like a cut"; `-S` over the pbxproj answers "what
actually changed the version", which is the question.

Then classify them, because a subject line hides things too — the same cut
found the entire Trophies tab shipped under "Backlog: E15 — team trophies":

```bash
for c in $(git log --format=%h --no-merges "$LAST"..HEAD); do
  git show --name-only --format= $c | grep -qE '^(sports/|StatSideShared/|StatSideWidgets/)' \
    && echo "iOS  $(git log -1 --format='%s' $c)" || echo "---  $(git log -1 --format='%s' $c)"
done
```

Only the `iOS` lines can reach the release notes. This repo carries `web/` and
a Vercel service too, and at the 2.3.0 cut exactly half the commits since the
last bump touched neither the app nor the widget.

Then decide the version with Andy if he hasn't named one. The build number
always increments, even for a metadata-only resubmission.

Read the commits since the last bump before writing anything — the release
notes and the listing audit both come out of that list, and it is also how you
catch a feature that shipped without a listing field noticing.

## Phase 1 — Bump the version

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` each appear **8 times** in
`sports.xcodeproj/project.pbxproj` — one per target (sports, sportsTests,
sportsUITests, StatSideWidgets) per configuration. All 16 move together.

```bash
sed -i '' \
  -e 's/MARKETING_VERSION = 2\.2\.0;/MARKETING_VERSION = 2.3.0;/g' \
  -e 's/CURRENT_PROJECT_VERSION = 16;/CURRENT_PROJECT_VERSION = 17;/g' \
  sports.xcodeproj/project.pbxproj
```

Escape the dots in the old version. Then verify all three of these:

```bash
plutil -lint sports.xcodeproj/project.pbxproj
grep -c 'MARKETING_VERSION = 2.3.0;' sports.xcodeproj/project.pbxproj   # 8
grep -c 'CURRENT_PROJECT_VERSION = 17;' sports.xcodeproj/project.pbxproj # 8
git diff --stat                                                          # 16 +, 16 -
```

Anything other than 16/16 means Xcode re-serialized the file — read the diff
before committing it. Never hand-edit file references in the pbxproj; build
settings are the only thing you touch there.

## Phase 2 — Listing audit, not just release notes

The trap this phase exists for: at 2.2.0 the subtitle, keywords, description
and review notes were all still two-league copy written for 2.0. Every one of
them is indexed or read by a reviewer.

1. Add a `### <version> (build <n>)` entry at the top of the **What's New**
   history in `docs/appstore/listing.md`. Newest first; keep the old entries.
   4000 chars max. Andy's voice — see the `anthropic-skills:andy-voice` skill
   if you're drafting rather than transcribing.
2. Walk the other fields against what actually changed, and fix what has gone
   stale: **Subtitle** (30), **Keywords** (100, comma-separated),
   **Promotional text** (170, editable without review), **Description** (4000),
   **App Review notes**. A field that names a subset of what the app now does
   is a bug.
3. Review notes matter more than their length suggests — the 4.2.2 rejection
   on build 5 was likely fed by an opener that described the app as displaying
   publicly available scores. Lead with native functionality.

## Phase 3 — Verify: tests, scoped and serial

CI (`.github/workflows/ci.yml`) runs build + `sportsTests` on every PR. The UI
suites are local-only, drive the live ESPN API, and **are exercised exactly
once per release — here.** Budget an hour for them.

```bash
UDID=$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro (' | grep -oE '[0-9A-F-]{36}')
xcodebuild test -project sports.xcodeproj -scheme sports \
  -destination "id=$UDID" -parallel-testing-enabled NO \
  -only-testing:sportsTests
```

Then the UI suites, in this order and never overlapping:

```bash
xcrun simctl uninstall "$UDID" com.andyryanweir.sports   # required before ReminderOffer
xcodebuild test -project sports.xcodeproj -scheme sports \
  -destination "id=$UDID" -parallel-testing-enabled NO \
  -only-testing:sportsUITests/SmokeUITests \
  -only-testing:sportsUITests/ReminderOfferUITests
```

Wait on `pgrep -x xcodebuild` before the next invocation — two runs fight over
the one simulator and both results are meaningless. Then, last and alone:

```bash
xcodebuild test -project sports.xcodeproj -scheme sports \
  -destination "id=$UDID" -parallel-testing-enabled NO \
  -only-testing:sportsUITests/WidgetUITests
xcrun simctl erase "$UDID"     # WidgetUITests leaves a widget on the Home Screen
```

Never run a bare `xcodebuild test` on the scheme: it also runs
`AppStoreScreenshots` (pure overhead here) and leaves widget state behind.

**When a UI suite fails.** Do not call it flake. The suites rot silently
between cuts — a behaviour change lands months before anyone runs them. At the
2.2.0 cut, Smoke and ReminderOffer had both been red since the NBA/NHL commit
because the Add-teams rows gained a split (body navigates, star follows) and
the helper still tapped the row. On a "no matches found" or "failed to tap",
drive that screen by hand in the simulator first; it settles in two minutes.
See CLAUDE.md § Running the UI tests for the six environment rules (the
`-ui.scoreFilter none` pin, the alert-tap breakage, Dynamic Type, the ghost
activations) and the `simulators-shared-across-sessions` memory — Andy taps
that simulator too, and another session may have clobbered the install.

## Phase 4 — Screenshots (only when they're wrong)

Screenshots carry forward automatically on a version update. Reshoot when the
frames say something the release makes false, or when the chrome under them
changed. `docs/appstore/listing.md` § Screenshots has the full mechanics; the
ones that bite:

- Upload the **1284×2778** copies. This account's drop zone rejects 1320×2868.
- Marketing frames (`screenshots-marketing-*`) are what goes up; the plain sets
  are masters. Both sizes render from `docs/social/src/as-*.html`.
- **Run the capture suite twice and keep the second set** — a fresh install
  shoots before team logos download and every crest lands as a grey disc.
- Set the status bar first (`simctl status_bar … --time "9:41"`), and pass the
  `TEST_RUNNER_SCREENSHOT_*` knobs for the day and follows being shot.
- Reshooting masters means re-rendering `docs/social/` — it crops into them at
  hardcoded offsets.

## Phase 5 — Archive and verify

```bash
VER=2.3.0; BUILD=17; DIR=~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)
mkdir -p "$DIR"
xcodebuild archive -project sports.xcodeproj -scheme sports \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$DIR/StatSide-$VER-$BUILD.xcarchive" \
  -allowProvisioningUpdates
```

`generic/platform=iOS` is required — with a simulator destination active you
get an archive Organizer refuses to distribute. `-allowProvisioningUpdates`
because signing is Automatic. Archive into the dated Archives directory so
Organizer finds it (also outside the repo, which has no tracked `.gitignore`).

Verify before handing anything over:

```bash
A="$DIR/StatSide-$VER-$BUILD.xcarchive"
plutil -p "$A/Products/Applications/StatSide.app/Info.plist" | grep -E 'CFBundleShortVersionString|CFBundleVersion'
plutil -p "$A/Products/Applications/StatSide.app/PlugIns/StatSideWidgets.appex/Info.plist" | grep -E 'CFBundleShortVersionString|CFBundleVersion'
ls "$A/dSYMs"            # exactly two entries
plutil -p "$A/Products/Applications/StatSide.app/Info.plist" | grep MinimumOSVersion
strings "$A/Products/Applications/StatSide.app/StatSide" | grep -cE 'liveactivity.enabled|data.provider'  # 0 = Release
```

App and appex versions must match, and `PlugIns/` must exist — build 1's
archive silently had no `PlugIns/` at all, which would have reopened the 4.2.2
rejection.

**If signing fails, check the push capability — don't delete the key.**
`Config/sports.entitlements` carries `aps-environment` again (restored
2026-09-15). It signs only while Push Notifications is enabled on the App ID
`com.andyryanweir.sports`. A signing failure naming a profile that "doesn't
include the aps-environment entitlement" means the capability is off; turn it
back on in the developer portal — deleting the key is how the Live Activities
sequence got lost the first time, and a CLI session can't re-add the capability
anyway (`xcodebuild` can't reach Xcode's stored account and reports "No
Accounts"). The file's own comment and
`docs/live-activities-service.md` § Creating the provider key have the sequence.

## Phase 6 — Hand off (do not upload unasked)

Default: report the archive path and the verification output, and stop. Andy
creates the ASC version record, uploads through Organizer, fills the fields
from `listing.md`, and submits.

**`Config/ExportOptions.plist` is a loaded gun.** It carries
`destination = upload`, and Xcode's stored credentials complete the upload with
no API key visible. `xcodebuild -exportArchive` with that plist **publishes to
App Store Connect immediately** — expect it to succeed, not to fail. Only run
it when Andy has asked for it in this session.

Two things to tell him every time, because both have cost a release:

1. **Create the ASC version record before uploading**, or the build has nothing
   to attach to.
2. **Don't build the submission until processing finishes.** "Upload
   Successful" only means the bits arrived; processing takes 5–15+ minutes and
   the build doesn't appear in the version page's Build section until it's
   done (the TestFlight tab is the honest view). Adding a build too early
   produces a persistent red *"There are errors with one or more of your
   items…"* that names nothing, doesn't clear on remove-and-re-add, and clears
   itself ~20 minutes later. Every ASC resource reports `VALID` the whole time
   — the error text exists only in the submit `PATCH` response. There is
   nothing to find. Wait it out.

If he wants the state read from outside: from a logged-in ASC tab,
`fetch('/iris/v1/…')` reaches `reviewSubmissions?filter[app]=<id>&include=items`,
`appStoreVersions/<id>?include=build`, and `builds/<id>`. Read-only.
`reviewSubmissionItems` rejects `GET_INSTANCE` — go through the parent's
`include=items`.

## Phase 7 — Land the commits, then record it

- Branch (`release/<version>`), PR, let CI go green, merge. Past cuts have been
  left unpushed on a release branch — check before the next one.
- The parity-ledger check (`scripts/check-parity-ledger.sh`) only fires when
  the PR adds a row to `docs/decisions.md`. A pure version bump adds none. If
  the cut also carries a product decision, add both rows; use `[skip-parity]`
  on its own line only for genuinely surfaceless work.
- Update the **`statside-app-store-status`** memory: version, build, archive
  path, what's in it, what was verified, what was knowingly waived, and its
  ASC state. That file is how the next cut knows what's live.
- Record anything new and expensive you learned in
  **`statside-release-mechanics`** rather than here, unless it's a step change.
