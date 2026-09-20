#!/usr/bin/env bash
#
# E20's P0 gate: does ESPN serve an athlete anything worth a page?
#
# The player page ships with one tab (Profile), built from the roster row that
# pushed it. Games, Stats and Career have no confirmed source — nobody has ever
# asked ESPN for one. This asks, across all four leagues, and prints enough to
# decide.
#
# Run it from a machine that can reach ESPN (agent sessions cannot — the egress
# proxy refuses the CONNECT), then paste the output into the E20 thread.
#
#     scripts/probe-athlete.sh              # all four leagues
#     scripts/probe-athlete.sh nhl          # one
#
# Athlete ids are real, lifted from the roster fixtures in sportsTests/, so a
# 404 means the endpoint is wrong rather than the player being made up.
#
# Reads nothing, writes nothing, sends no credentials. Be a polite guest: it
# makes at most 20 requests and sleeps between them.

set -uo pipefail

SLEEP="${PROBE_SLEEP:-0.4}"
OUT="${PROBE_OUT:-}"

# league | sport segment | league segment | athlete id | who that is
LEAGUES=(
  "cfb|football|college-football|5276651|Brayden Allen, Ole Miss WR"
  "nfl|football|nfl|4912218|Cyrus Allen, Kansas City"
  "nba|basketball|nba|3945274|Luka Doncic, Lakers"
  "nhl|hockey|nhl|4565224|Kirby Dach, Montreal"
)

want="${1:-all}"

# What each candidate is being asked to prove, in E20's own terms.
#   profile  — is there a bio at all, and does it carry a hometown?
#   gamelog  — the Games tab, and the fallback Career is built from
#   stats    — the Stats tab, and the Current season card
#   overview — sometimes carries season totals next to the bio
#   core     — the $ref-heavy core API, the last resort
urls_for() {
  local sport="$1" league="$2" id="$3"
  cat <<EOF
profile|https://site.web.api.espn.com/apis/common/v3/sports/${sport}/${league}/athletes/${id}
gamelog|https://site.web.api.espn.com/apis/common/v3/sports/${sport}/${league}/athletes/${id}/gamelog
stats|https://site.web.api.espn.com/apis/common/v3/sports/${sport}/${league}/athletes/${id}/stats
overview|https://site.web.api.espn.com/apis/common/v3/sports/${sport}/${league}/athletes/${id}/overview
siteapi|https://site.api.espn.com/apis/site/v2/sports/${sport}/${league}/athletes/${id}
core|https://sports.core.api.espn.com/v2/sports/${sport}/leagues/${league}/athletes/${id}
EOF
}

# Top-level keys, plus the handful of words that decide a tab. Falls back to a
# byte count if python3 is missing, which is still enough to tell 200-with-data
# from 200-with-nothing.
summarize() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
raw = sys.stdin.buffer.read()
print("      bytes: %d" % len(raw))
try:
    d = json.loads(raw)
except Exception as e:
    print("      not JSON (%s)" % type(e).__name__)
    sys.exit()
if isinstance(d, dict):
    keys = sorted(d.keys())
    print("      keys: %s" % (", ".join(keys[:18]) + (" …" if len(keys) > 18 else "")))
else:
    print("      top level is a %s" % type(d).__name__)
text = raw.decode("utf-8", "replace")
marks = ["birthPlace", "birthCity", "hometown", "college", "draft",
         "gamelog", "seasonTypes", "statistics", "splits", "displayValue",
         "teamHistory", "careerStats", "$ref"]
hits = [m for m in marks if "\"%s\"" % m in text or m == "$ref" and "$ref" in text]
print("      carries: %s" % (", ".join(hits) if hits else "none of the markers"))
'
  else
    printf '      bytes: %s (install python3 for a key summary)\n' "$(wc -c)"
  fi
}

probe_one() {
  local label="$1" url="$2" body status
  body="$(mktemp)"
  # `|| echo` here would concatenate onto curl's own %{http_code}, which
  # prints "000" before it exits non-zero — that reads as 000000.
  status="$(curl -sS -o "$body" -w '%{http_code}' --max-time 25 \
             -H 'Accept: application/json' "$url" 2>/dev/null)" || true
  [ -n "$status" ] || status="000"
  printf '  %-9s %s\n' "$label" "$status"
  printf '      %s\n' "$url"
  if [ "$status" = "200" ]; then
    summarize < "$body"
  elif [ "$status" = "000" ]; then
    printf '      no answer — network, DNS or a proxy refusing the CONNECT\n'
  fi
  rm -f "$body"
  sleep "$SLEEP"
}

run() {
  printf 'ESPN athlete probe — %s\n' "$(date -u '+%Y-%m-%d %H:%MZ')"
  printf 'E20 P0. Record the result in ARCHITECTURE.md whichever way it goes.\n'

  for row in "${LEAGUES[@]}"; do
    IFS='|' read -r lg sport league id who <<< "$row"
    [ "$want" = "all" ] || [ "$want" = "$lg" ] || continue
    printf '\n=== %s — athlete %s (%s) ===\n' "$lg" "$id" "$who"
    while IFS='|' read -r label url; do
      [ -n "$label" ] && probe_one "$label" "$url"
    done < <(urls_for "$sport" "$league" "$id")
  done

  printf '\nWhat to look for:\n'
  printf '  A 200 whose "carries" line names gamelog/seasonTypes/statistics is the Games\n'
  printf '  and Stats tabs existing. birthPlace is the Profile hometown row. teamHistory\n'
  printf '  or careerStats is Career without having to derive it from logs.\n'
}

if [ -n "$OUT" ]; then
  run | tee "$OUT"
  printf '\nSaved to %s\n' "$OUT"
else
  run
fi
