#!/usr/bin/env bash
#
# PR shepherd — keeps the author's open PRs moving toward auto-merge.
#
# For each open, non-draft PR the configured author opened, in order:
#
#   1. CONFLICTS   If the PR conflicts with main, merge main into the branch.
#                  Conflicts confined to the docs ledgers are resolved by
#                  keeping both sides (they are append-only tables); a
#                  conflict in anything else is left alone and the PR is
#                  labelled `needs-human`. The merge is pushed with a plain
#                  `git push` — never a force-push.
#   2. CI          If a required check failed, decide whether it is flaky by
#                  asking whether main's latest run of the same workflow
#                  failed on the same test. Flaky: re-run the failed jobs
#                  once per head commit. Real: hand the failing log to
#                  `claude -p` with a tool set that can only edit test and
#                  snapshot files; anything it touches outside that set is
#                  reverted and the PR is labelled `needs-human`.
#   3. AUTO-MERGE  Enable `gh pr merge --auto --squash` if it isn't already.
#                  Never `--admin`, never a direct merge.
#   4. COMMENT     Post one short comment saying what it did, if it did
#                  anything. A silent pass posts nothing.
#
# `--dry-run` performs every read, every local merge and every diagnosis, but
# pushes nothing, labels nothing, reruns nothing, comments nothing, and runs
# `claude` with read-only tools so the fix attempt is a proposal, not a push.
#
# Hard rules this script enforces rather than asks for:
#   - no `--force` anywhere; pushes are `git push origin HEAD:refs/heads/<b>`
#   - no `gh pr merge` except `--auto --squash`
#   - `claude` runs with `--permission-mode dontAsk` and an explicit allow
#     list; `git push`, `gh`, and anything destructive are disallowed tools
#   - a `needs-human` label stops the shepherd from touching that PR again
#     until a person removes it
#
# Usage:
#   scripts/pr-shepherd.sh [--dry-run] [--pr <number>] [--author <login>]
#
# Environment:
#   GH_TOKEN / GITHUB_TOKEN   gh auth (a PAT in CI, so pushes re-trigger CI)
#   ANTHROPIC_API_KEY         for claude -p (or a logged-in claude locally)
#   SHEPHERD_AUTHOR           PR author to shepherd (default: the gh user)
#   SHEPHERD_LABEL            default `needs-human`
#   SHEPHERD_MODEL            model for claude -p (default: claude's default)
#   SHEPHERD_MAX_BUDGET_USD   per fix attempt (default 5)
#   SHEPHERD_REPO             owner/name (default: from the checkout)

set -euo pipefail

DRY_RUN=0
ONLY_PR=""
AUTHOR="${SHEPHERD_AUTHOR:-}"
LABEL="${SHEPHERD_LABEL:-needs-human}"
MODEL="${SHEPHERD_MODEL:-}"
MAX_BUDGET="${SHEPHERD_MAX_BUDGET_USD:-5}"
BASE_BRANCH="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --pr) ONLY_PR="$2"; shift ;;
    --author) AUTHOR="$2"; shift ;;
    -h|--help) sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
REPO="${SHEPHERD_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
[ -n "$AUTHOR" ] || AUTHOR="$(gh api user --jq .login)"
WORK="$(mktemp -d -t pr-shepherd.XXXXXX)"
trap 'cleanup' EXIT

# Conflicts the shepherd may resolve on its own: the two frozen ledgers
# (append-only tables; both sides are kept) and per-PR change files, which
# shouldn't conflict at all but are docs if they do. Nothing else.
DOCS_CONFLICT_RE='^docs/(decisions\.md|web-parity\.md|changes/[^/]+\.md)$'

# Files a CI-fix attempt may change. Tests and snapshots only — a failing
# product file is a product decision, and those get a human.
FIX_ALLOWED_RE='^(sportsTests/|sportsUITests/|web/src/.*\.test\.(ts|tsx|js|jsx)$|web/.*/__snapshots__/|web/.*\.snap$|web/src/test/)'

MARK='<!-- pr-shepherd -->'

cleanup() {
  for wt in "$WORK"/wt-*; do
    [ -d "$wt" ] && git worktree remove --force "$wt" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}

say()  { printf '%s\n' "$*"; }
act()  { ACTIONS+=("$*"); say "  → $*"; }
plan() { ACTIONS+=("(dry run) would: $*"); say "  ⇢ would: $*"; }
note() { NOTES+=("$*"); say "  · $*"; }

# A thing that writes to GitHub or the remote: skipped in a dry run.
do_or_plan() {
  local what="$1"; shift
  if [ "$DRY_RUN" = 1 ]; then plan "$what"; return 0; fi
  if "$@"; then act "$what"; else note "FAILED: $what"; fi
}

ensure_label() {
  if ! gh label list --repo "$REPO" --json name --jq '.[].name' | grep -qx "$LABEL"; then
    if [ "$DRY_RUN" = 1 ]; then
      say "  ⇢ would: create label '$LABEL'"
    else
      gh label create "$LABEL" --repo "$REPO" --color B60205 \
        --description "The PR shepherd found something only a person should decide" >/dev/null
    fi
  fi
}

label_needs_human() {
  local pr="$1" why="$2"
  NEEDS_HUMAN="$why"
  do_or_plan "label '$LABEL' — $why" gh pr edit "$pr" --repo "$REPO" --add-label "$LABEL"
}

# ---------------------------------------------------------------- 1. conflicts

# Union-resolve one conflicted path from its three index stages. The frozen
# ledgers are tables where both sides appended a row, so "keep both" is the
# right answer by construction; this is what `merge=union` does, done by
# hand for branches whose .gitattributes predate it.
union_resolve() {
  local path="$1"
  git show ":1:$path" > "$WORK/base" 2>/dev/null || : > "$WORK/base"
  git show ":2:$path" > "$WORK/ours"
  git show ":3:$path" > "$WORK/theirs"
  git merge-file -p --union "$WORK/ours" "$WORK/base" "$WORK/theirs" > "$path" || true
  git add "$path"
}

handle_conflicts() {
  local pr="$1" branch="$2"
  local wt="$WORK/wt-$pr"
  git fetch -q origin "$BASE_BRANCH" "$branch"
  git worktree add -q --detach "$wt" "origin/$branch"
  (
    cd "$wt"
    git config user.name  "${GIT_AUTHOR_NAME:-pr-shepherd}"
    git config user.email "${GIT_AUTHOR_EMAIL:-pr-shepherd@users.noreply.github.com}"
    if git merge -q --no-edit "origin/$BASE_BRANCH" >/dev/null 2>&1; then
      echo "clean"
      exit 0
    fi
    conflicted="$(git diff --name-only --diff-filter=U)"
    others="$(printf '%s\n' "$conflicted" | grep -vE "$DOCS_CONFLICT_RE" || true)"
    if [ -n "$others" ]; then
      git merge --abort
      echo "product:$(printf '%s' "$others" | tr '\n' ' ')"
      exit 0
    fi
    while IFS= read -r path; do
      [ -n "$path" ] && union_resolve "$path"
    done <<< "$conflicted"
    git commit -q --no-edit
    echo "docs:$(printf '%s' "$conflicted" | tr '\n' ' ')"
  ) > "$WORK/merge-result" 2>"$WORK/merge-err" || {
    note "merge of $BASE_BRANCH failed unexpectedly: $(head -c 300 "$WORK/merge-err")"
    return 0
  }
  local result; result="$(cat "$WORK/merge-result")"
  case "$result" in
    clean)
      do_or_plan "merge $BASE_BRANCH into $branch (no conflicts) and push" \
        git -C "$wt" push -q origin "HEAD:refs/heads/$branch"
      ;;
    docs:*)
      do_or_plan "merge $BASE_BRANCH into $branch, keeping both sides of ${result#docs:}, and push" \
        git -C "$wt" push -q origin "HEAD:refs/heads/$branch"
      ;;
    product:*)
      label_needs_human "$pr" "conflicts with $BASE_BRANCH in product files: ${result#product:}"
      ;;
  esac
  if [ "$DRY_RUN" = 1 ] && [ "${result%%:*}" != "product" ]; then
    say "    merge commit (not pushed):"
    git -C "$wt" log -1 --format='    %h %s' && git -C "$wt" diff --stat HEAD~1 HEAD | tail -1 | sed 's/^/   /'
  fi
}

# ---------------------------------------------------------------------- 2. CI

# Failing test identifiers from a run's failed-step log. Two dialects:
# xcodebuild ("Test Case '-[sportsTests.X testY]' failed") and vitest
# (" × path > name" / "FAIL  path > name"). Anything else — a build error, a
# dead simulator — yields no ids, which the caller treats differently.
failing_tests_in_run() {
  local run_id="$1"
  gh run view "$run_id" --repo "$REPO" --log-failed 2>/dev/null \
    | python3 -I -c '
import re, sys
ids = set()
for line in sys.stdin:
    m = re.search(r"Test Case .-\[(\S+) (\S+)\]. failed", line)
    if m: ids.add("%s/%s" % (m.group(1), m.group(2)))
    m = re.search(r"(?:^|\s)(?:×|✗|FAIL)\s+(\S+\.test\.\w+)\s*>\s*(.+?)\s*(?:\d+ms)?$", line)
    if m: ids.add("%s > %s" % (m.group(1), m.group(2).strip()))
for i in sorted(ids): print(i)
'
}

latest_main_run() {
  local workflow="$1"
  gh run list --repo "$REPO" --workflow "$workflow" --branch "$BASE_BRANCH" \
    --status completed --limit 1 --json databaseId,conclusion \
    --jq '.[0] | "\(.databaseId) \(.conclusion)"' 2>/dev/null || true
}

# The shepherd's own earlier comments carry markers so "once" means once:
#   <!-- pr-shepherd rerun=<sha> -->   <!-- pr-shepherd fix=<sha> -->
already_done() {
  local pr="$1" kind="$2" sha="$3"
  gh pr view "$pr" --repo "$REPO" --json comments --jq '.comments[].body' \
    | grep -q "<!-- pr-shepherd $kind=$sha -->"
}

attempt_test_fix() {
  local pr="$1" branch="$2" sha="$3" workflow="$4" run_id="$5" tests="$6"
  local wt="$WORK/wt-fix-$pr"
  git fetch -q origin "$branch"
  git worktree add -q --detach "$wt" "origin/$branch"
  gh run view "$run_id" --repo "$REPO" --log-failed 2>/dev/null | tail -n 400 > "$WORK/failed.log" || true

  local prompt
  prompt="$(cat <<EOF
You are the PR shepherd for $REPO, working in a checkout of branch \`$branch\` (PR #$pr, head $sha).
The \`$workflow\` workflow failed on this branch, and the same tests pass on $BASE_BRANCH, so the failure is real.

Failing tests:
$tests

Last 400 lines of the failed step's log:
\`\`\`
$(cat "$WORK/failed.log")
\`\`\`

Your job is narrow: make these tests pass by changing ONLY test files or stale snapshots —
paths under sportsTests/, sportsUITests/, web/src/**/*.test.ts(x), web/**/__snapshots__/, *.snap.
Read the product code the test exercises to understand what changed, and update the test's
expectation to match the product's new, intended behavior. If the test is right and the product
is wrong, or if a fix needs a change outside those paths, change NOTHING and explain why in one
paragraph starting with "NEEDS-HUMAN:". Do not run git push, do not open PRs, do not touch CI config.
For web tests you may run \`npm test\` inside web/ to verify; the iOS tests cannot run here, so
keep Swift edits minimal and obviously correct. When done, print a 2–3 sentence summary of what
you changed and why, in plain language, for a PR comment.
EOF
)"

  local -a claude_args=(-p --output-format json --max-turns 40 --max-budget-usd "$MAX_BUDGET"
    --permission-mode dontAsk --no-session-persistence
    --disallowedTools 'Bash(git push:*)' 'Bash(git push)' 'Bash(gh:*)' 'Bash(rm:*)' 'Bash(git reset:*)' 'Bash(git checkout:*)' 'WebFetch' 'WebSearch')
  if [ "$DRY_RUN" = 1 ]; then
    claude_args+=(--allowedTools 'Read' 'Grep' 'Glob' 'Bash(git diff:*)' 'Bash(git log:*)' 'Bash(git status:*)' 'Bash(ls:*)' 'Bash(cat:*)')
    prompt="$prompt

THIS IS A DRY RUN: you have read-only tools. Do not attempt edits; instead describe exactly which
file(s) you would change and how, or say NEEDS-HUMAN: with the reason."
  else
    claude_args+=(--allowedTools 'Read' 'Grep' 'Glob' 'Edit' 'Write' 'MultiEdit' 'Bash(git diff:*)' 'Bash(git log:*)' 'Bash(git status:*)' 'Bash(ls:*)' 'Bash(cat:*)' 'Bash(npm test:*)' 'Bash(npx vitest:*)' 'Bash(npm ci:*)')
  fi
  [ -n "$MODEL" ] && claude_args+=(--model "$MODEL")

  say "  · asking claude -p to $( [ "$DRY_RUN" = 1 ] && echo 'propose' || echo 'attempt' ) a test-only fix (budget \$$MAX_BUDGET)"
  local summary cost
  if ! (cd "$wt" && claude "${claude_args[@]}" "$prompt") > "$WORK/claude.json" 2>"$WORK/claude.err"; then
    note "claude -p failed: $(head -c 300 "$WORK/claude.err")"
    return 0
  fi
  summary="$(python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(d.get("result",""))' < "$WORK/claude.json")"
  cost="$(python3 -I -c 'import json,sys; d=json.load(sys.stdin); print("%.2f" % d.get("total_cost_usd",0))' < "$WORK/claude.json")"
  say "    claude (\$$cost): $(printf '%s' "$summary" | head -c 600 | tr '\n' ' ')"

  if [ "$DRY_RUN" = 1 ]; then
    plan "attempt a test-only fix for ${tests//$'\n'/, } — proposal above"
    return 0
  fi
  if printf '%s' "$summary" | grep -q 'NEEDS-HUMAN:'; then
    label_needs_human "$pr" "claude declined a test-only fix: $(printf '%s' "$summary" | sed -n 's/.*NEEDS-HUMAN: *//p' | head -c 300)"
    return 0
  fi
  local changed disallowed
  changed="$(git -C "$wt" status --porcelain | awk '{print $2}')"
  if [ -z "$changed" ]; then
    label_needs_human "$pr" "claude made no change for the real CI failure (${tests//$'\n'/, })"
    return 0
  fi
  disallowed="$(printf '%s\n' "$changed" | grep -vE "$FIX_ALLOWED_RE" || true)"
  if [ -n "$disallowed" ]; then
    git -C "$wt" checkout -q -- . && git -C "$wt" clean -qfd
    label_needs_human "$pr" "a fix would touch product files ($(printf '%s' "$disallowed" | tr '\n' ' ')) — reverted"
    return 0
  fi
  (
    cd "$wt"
    git config user.name  "${GIT_AUTHOR_NAME:-pr-shepherd}"
    git config user.email "${GIT_AUTHOR_EMAIL:-pr-shepherd@users.noreply.github.com}"
    git add -A
    git commit -q -m "pr-shepherd: test-only fix for $workflow

$(printf '%s' "$summary" | head -c 1500)

Co-Authored-By: Claude <noreply@anthropic.com>"
    git push -q origin "HEAD:refs/heads/$branch"
  )
  act "pushed a test-only fix ($(printf '%s' "$changed" | tr '\n' ' ')): $(printf '%s' "$summary" | head -c 300 | tr '\n' ' ')"
  FIX_SHA="$sha"
}

handle_ci() {
  local pr="$1" branch="$2" sha="$3"
  local checks
  checks="$(gh pr view "$pr" --repo "$REPO" --json statusCheckRollup --jq '
    .statusCheckRollup[]? | select(.__typename == "CheckRun")
    | "\(.conclusion // .status)\t\(.workflowName // "")\t\(.name)\t\(.detailsUrl // "")"')"
  if [ -z "$checks" ]; then note "no checks reported yet"; return 0; fi
  local pending; pending="$(printf '%s\n' "$checks" | grep -cE '^(IN_PROGRESS|QUEUED|PENDING|WAITING|)\s' || true)"
  local failed; failed="$(printf '%s\n' "$checks" | grep -E '^(FAILURE|TIMED_OUT)\s' || true)"
  if [ -z "$failed" ]; then
    if [ "$pending" -gt 0 ]; then note "CI: $pending check(s) still running"; else note "CI green"; fi
    return 0
  fi
  while IFS=$'\t' read -r conclusion workflow name url; do
    [ -n "$name" ] || continue
    local run_id; run_id="$(printf '%s' "$url" | sed -nE 's#.*/actions/runs/([0-9]+).*#\1#p')"
    say "  · failed check: $name ($workflow, run ${run_id:-?})"
    if [ -z "$run_id" ] || [ -z "$workflow" ]; then
      note "cannot map '$name' to a workflow run — leaving it"
      continue
    fi
    local tests; tests="$(failing_tests_in_run "$run_id")"
    local main_run main_id main_conclusion main_tests=""
    main_run="$(latest_main_run "$workflow")"
    main_id="${main_run%% *}"; main_conclusion="${main_run##* }"
    [ -n "$main_id" ] && [ "$main_conclusion" = "failure" ] && main_tests="$(failing_tests_in_run "$main_id")"
    local verdict="real"
    if [ "$main_conclusion" = "failure" ]; then
      if [ -z "$tests" ] || [ -n "$(comm -12 <(printf '%s\n' "$tests" | sort) <(printf '%s\n' "$main_tests" | sort))" ]; then
        verdict="flaky"
      fi
    fi
    if [ -n "$tests" ]; then say "    failing: $(printf '%s' "$tests" | tr '\n' ',' | head -c 300)"; else say "    no test ids in the log (build or runner failure)"; fi
    say "    $BASE_BRANCH latest $workflow run: ${main_conclusion:-none} → $verdict"
    if [ "$verdict" = "flaky" ]; then
      if already_done "$pr" rerun "$sha"; then
        label_needs_human "$pr" "$name still fails after its one re-run at $sha (flaky on $BASE_BRANCH too)"
      else
        do_or_plan "re-run failed jobs of $workflow run $run_id once (same failure on $BASE_BRANCH)" \
          gh run rerun "$run_id" --repo "$REPO" --failed
        RERUN_SHA="$sha"
      fi
      continue
    fi
    if [ -z "$tests" ]; then
      label_needs_human "$pr" "$name fails without a test failure (build/runner error) and $BASE_BRANCH is green"
      continue
    fi
    if already_done "$pr" fix "$sha"; then
      label_needs_human "$pr" "$name still fails after a shepherd fix attempt at $sha"
      continue
    fi
    attempt_test_fix "$pr" "$branch" "$sha" "$workflow" "$run_id" "$tests"
  done <<< "$failed"
}

# --------------------------------------------------------------- 3. auto-merge

handle_auto_merge() {
  local pr="$1" auto="$2"
  if [ "$auto" = "true" ]; then note "auto-merge already enabled"; return 0; fi
  do_or_plan "enable auto-merge (squash)" gh pr merge "$pr" --repo "$REPO" --auto --squash
}

# ------------------------------------------------------------------ 4. comment

post_comment() {
  local pr="$1"
  [ "${#ACTIONS[@]}" -gt 0 ] || { say "  · nothing to report, no comment"; return 0; }
  local body="**PR shepherd** ($(date -u +%Y-%m-%d\ %H:%MZ))"$'\n'
  local a; for a in "${ACTIONS[@]}"; do body+="- $a"$'\n'; done
  [ -n "${NEEDS_HUMAN:-}" ] && body+=$'\n'"Labelled \`$LABEL\`; the shepherd leaves this PR alone until the label is removed."$'\n'
  body+=$'\n'"$MARK"
  [ -n "${RERUN_SHA:-}" ] && body+=$'\n'"<!-- pr-shepherd rerun=$RERUN_SHA -->"
  [ -n "${FIX_SHA:-}" ]   && body+=$'\n'"<!-- pr-shepherd fix=$FIX_SHA -->"
  if [ "$DRY_RUN" = 1 ]; then
    say "  ⇢ would comment:"; printf '%s\n' "$body" | grep -v '^<!--' | sed 's/^/      /'
  else
    gh pr comment "$pr" --repo "$REPO" --body "$body" >/dev/null && say "  → commented"
  fi
}

# ------------------------------------------------------------------------ main

say "PR shepherd — $REPO, PRs by $AUTHOR$( [ "$DRY_RUN" = 1 ] && echo ' (DRY RUN: nothing is pushed, labelled, re-run or commented)')"
ensure_label

if [ -n "$ONLY_PR" ]; then
  prs="$(gh pr view "$ONLY_PR" --repo "$REPO" --json number --jq .number)"
else
  prs="$(gh pr list --repo "$REPO" --state open --author "$AUTHOR" --base "$BASE_BRANCH" --limit 50 --json number --jq '.[].number')"
fi
if [ -z "$prs" ]; then say "No open PRs by $AUTHOR against $BASE_BRANCH. Nothing to do."; exit 0; fi

for pr in $prs; do
  ACTIONS=(); NOTES=(); NEEDS_HUMAN=""; RERUN_SHA=""; FIX_SHA=""
  meta="$(gh pr view "$pr" --repo "$REPO" --json number,title,isDraft,headRefName,headRefOid,mergeable,mergeStateStatus,autoMergeRequest,labels \
    --jq '[.title, (.isDraft|tostring), .headRefName, .headRefOid, .mergeable, .mergeStateStatus, ((.autoMergeRequest != null)|tostring), ([.labels[].name]|join(","))] | @tsv')"
  IFS=$'\t' read -r title draft branch sha mergeable state auto labels <<< "$meta"
  say ""
  say "#$pr $title"
  say "  branch $branch @ ${sha:0:7} · mergeable=$mergeable state=$state auto-merge=$auto labels=[${labels}]"
  if [ "$draft" = "true" ]; then say "  · draft — skipped"; continue; fi
  if printf '%s' ",$labels," | grep -q ",$LABEL,"; then say "  · carries '$LABEL' — waiting on a person, skipped"; continue; fi

  if [ "$mergeable" = "CONFLICTING" ]; then
    handle_conflicts "$pr" "$branch"
  elif [ "$mergeable" = "UNKNOWN" ]; then
    note "GitHub hasn't computed mergeability yet — next pass"
  else
    note "no conflicts with $BASE_BRANCH"
  fi
  [ -z "$NEEDS_HUMAN" ] && handle_ci "$pr" "$branch" "$sha"
  [ -z "$NEEDS_HUMAN" ] && handle_auto_merge "$pr" "$auto"
  post_comment "$pr"
done
