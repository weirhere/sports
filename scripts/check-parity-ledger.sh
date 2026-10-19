#!/usr/bin/env bash
#
# The web-parity coupling, enforced — second form.
#
# `web/` and the iOS app are two implementations of one product, and nothing
# in the build couples them. The 2026-09-01 parity port had nothing holding
# it and decayed to 1.x in eight days — 89 iOS decision rows, one of which
# reached the web. This check is the coupling.
#
# First form (2026-09-10 to 2026-10-19): count the rows a branch added to
# docs/decisions.md and require as many in docs/web-parity.md. It worked, and
# it made every PR write the last line of two shared tables — which is why 31
# of the last 80 merged PRs conflicted on a row nobody disagreed about.
#
# Second form: both ledgers are frozen. Each PR writes docs/changes/<pr>.md,
# and the parity status is a required section *inside* that file, so there is
# nothing to count and nothing to skip. This script now delegates to
# scripts/build-changelog.py, which validates every change file and fails the
# branch if it grew a frozen ledger. The name is kept so CLAUDE.md, the PR
# template, the cut-release skill and web-ci.yml keep pointing somewhere true.

set -euo pipefail

BASE_REF="${1:-origin/main}"
exec python3 "$(dirname "$0")/build-changelog.py" check "$BASE_REF"
