#!/usr/bin/env python3
"""
The decisions log and the web-parity ledger, assembled from one file per PR.

Why this exists. Until 2026-10-19 every PR appended a row to the end of
`docs/decisions.md` and another to the end of `docs/web-parity.md`. Two
append-only tables that every PR writes the last line of conflict with each
other by construction: of the 80 PRs merged before this script, 72 touched
a ledger and 31 had another ledger PR merge while they were open — a
guaranteed conflict on the same trailing line, resolved by hand each time.

The fix is structural. Each PR now writes its own file, `docs/changes/<pr>.md`,
and never touches a shared one. Two files from two PRs cannot conflict. The
tables people actually read — the full log, the full ledger — are *built*
from those files plus the frozen pre-cutover history, and never committed.

    scripts/build-changelog.py build [--out docs/generated]
        Write docs/generated/decisions.md and docs/generated/web-parity.md:
        the frozen file, then one row per entry under docs/changes/, sorted
        by date then PR number.

    scripts/build-changelog.py check [BASE_REF]
        CI gate. Every change file parses, carries a date, at least one
        decision with a reason and a web-parity status, and a `pr:` that
        matches its filename. Fails if the branch adds rows to a frozen
        ledger — those are closed; the row belongs in docs/changes/.

    scripts/build-changelog.py status
        Web parity counted across the frozen ledger and every change file.

Format of a change file (docs/changes/README.md has the long version):

    ---
    pr: 276
    date: 2026-10-19
    ---

    ## Decision
    **Bold headline.** What changed, in the voice of the log.

    ## Why
    The reasoning — not just the change.

    ## Web parity
    pending — what the web still has to do

    ## Backlog
    BACKLOG E29            (optional; the log's fourth column)

A file may hold several decisions: each `## Decision` starts a new entry,
and the `## Why` / `## Web parity` / `## Backlog` that follow attach to it.

Stdlib only, Python 3.9+ (the dev Macs ship 3.9; CI runners ship newer).
"""

import argparse
import os
import re
import subprocess
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGES_DIR = os.path.join(REPO, "docs", "changes")
FROZEN_DECISIONS = os.path.join(REPO, "docs", "decisions.md")
FROZEN_LEDGER = os.path.join(REPO, "docs", "web-parity.md")
DEFAULT_OUT = os.path.join(REPO, "docs", "generated")

STATUSES = ("shipped", "pending", "n/a", "differs")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
FILENAME_RE = re.compile(r"^(\d+)(?:-[a-z0-9-]+)?\.md$")
HEADING_RE = re.compile(r"^##\s+(Decision|Why|Web parity|Backlog)\s*$", re.I)

# The frozen files' own row shapes, kept identical to what
# check-parity-ledger.sh counted before the cutover so the two numbers agree.
DECISION_ROW_RE = re.compile(r"^\| \d{4}-\d{2}-\d{2} \|")
LEDGER_ROW_RE = re.compile(r"^\| (\d{4}-\d{2}-\d{2}|—)[^|]*\|")


class Entry:
    def __init__(self, pr, date, path):
        self.pr = pr
        self.date = date
        self.path = path
        self.decision = ""
        self.why = ""
        self.parity = ""
        self.backlog = ""

    @property
    def status(self):
        lead = self.parity.strip().lower()
        for key in STATUSES:
            if lead.startswith(key):
                return key
        return None


def rel(path):
    return os.path.relpath(path, REPO)


def cell(text):
    """One table cell: paragraphs joined, pipes escaped, no raw newlines."""
    paragraphs = [" ".join(p.split()) for p in re.split(r"\n\s*\n", text.strip()) if p.strip()]
    return " ".join(paragraphs).replace("|", "\\|")


def parse_change_file(path):
    """Return (entries, problems). Problems are strings; entries may be partial."""
    problems = []
    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        return [], ["no frontmatter block (--- / pr: / date: / ---) at the top"]
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip().lower()] = v.strip()
    body = m.group(2)

    pr = meta.get("pr", "")
    date = meta.get("date", "")
    if not pr.isdigit():
        problems.append("frontmatter `pr:` must be the PR number (got %r)" % pr)
    if not DATE_RE.match(date):
        problems.append("frontmatter `date:` must be YYYY-MM-DD (got %r)" % date)
    fm = FILENAME_RE.match(os.path.basename(path))
    if not fm:
        problems.append("filename must be <pr-number>.md or <pr-number>-<slug>.md")
    elif pr.isdigit() and fm.group(1) != pr:
        problems.append("filename says PR %s but frontmatter says pr: %s" % (fm.group(1), pr))

    entries = []
    current = None
    section = None
    buf = []

    def flush():
        if current is not None and section is not None:
            setattr(current, section, "\n".join(buf).strip())

    for line in body.splitlines():
        h = HEADING_RE.match(line)
        if h:
            flush()
            name = h.group(1).lower()
            if name == "decision":
                current = Entry(int(pr) if pr.isdigit() else 0, date, path)
                entries.append(current)
                section = "decision"
            elif current is None:
                problems.append("`## %s` before any `## Decision`" % h.group(1))
                section = None
            else:
                section = {"why": "why", "web parity": "parity", "backlog": "backlog"}[name]
            buf = []
        else:
            buf.append(line)
    flush()

    if not entries:
        problems.append("no `## Decision` section")
    for i, e in enumerate(entries, 1):
        tag = "" if len(entries) == 1 else " (decision %d)" % i
        if not e.decision:
            problems.append("`## Decision`%s is empty" % tag)
        if not e.why:
            problems.append("`## Why`%s is missing or empty — the reasoning is the point of the log" % tag)
        if not e.parity:
            problems.append("`## Web parity`%s is missing — say shipped / pending / n/a / differs, then why" % tag)
        elif e.status is None:
            problems.append("`## Web parity`%s must start with one of %s" % (tag, ", ".join(STATUSES)))
    return entries, problems


def load_entries(strict=False):
    entries, bad = [], {}
    if os.path.isdir(CHANGES_DIR):
        for name in sorted(os.listdir(CHANGES_DIR)):
            if not name.endswith(".md") or name.upper() == "README.MD":
                continue
            path = os.path.join(CHANGES_DIR, name)
            found, problems = parse_change_file(path)
            if problems:
                bad[path] = problems
            entries.extend(found)
    entries.sort(key=lambda e: (e.date, e.pr))
    if strict and bad:
        return entries, bad
    return entries, bad


def frozen_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().rstrip("\n") + "\n"


def decisions_rows(entries):
    rows = []
    for e in entries:
        cells = [e.date, cell(e.decision), cell(e.why)]
        if e.backlog:
            cells.append(cell(e.backlog))
        rows.append("| " + " | ".join(cells) + " |")
    return rows


def ledger_rows(entries):
    rows = []
    for e in entries:
        status, _, note = e.parity.strip().partition(" ")
        note = note.strip().lstrip("—-: ").strip()
        headline = cell(e.decision)
        # The log's bold headline is the row's name; the sentence after it is
        # detail the ledger doesn't need twice.
        bold = re.match(r"\*\*(.+?)\*\*", headline)
        if bold:
            headline = bold.group(1)
        rows.append("| %s | %s | **%s**%s |" % (e.date, headline, e.status, (" — " + cell(note)) if note else ""))
    return rows


def cmd_build(args):
    entries, bad = load_entries()
    if bad:
        report_bad(bad)
        return 1
    os.makedirs(args.out, exist_ok=True)

    dec_path = os.path.join(args.out, "decisions.md")
    with open(dec_path, "w", encoding="utf-8") as fh:
        fh.write(frozen_text(FROZEN_DECISIONS))
        if entries:
            fh.write("\n".join(decisions_rows(entries)) + "\n")

    led_path = os.path.join(args.out, "web-parity.md")
    with open(led_path, "w", encoding="utf-8") as fh:
        fh.write(frozen_text(FROZEN_LEDGER))
        if entries:
            fh.write("\n## Since the cutover — one row per PR, from `docs/changes/`\n\n")
            fh.write("| iOS date | Decision | Status |\n|---|---|---|\n")
            fh.write("\n".join(ledger_rows(entries)) + "\n")

    prs = sorted({e.pr for e in entries})
    print("built %s and %s: %d decision(s) from %d PR file(s) on top of the frozen history"
          % (rel(dec_path), rel(led_path), len(entries), len(prs)))
    return 0


def report_bad(bad):
    for path, problems in bad.items():
        print("✗ %s" % rel(path))
        for p in problems:
            print("    - %s" % p)


def git_show(ref, path):
    try:
        return subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=REPO, check=True,
                              capture_output=True, text=True).stdout
    except subprocess.CalledProcessError:
        return ""


def count_rows(text, pattern):
    return sum(1 for line in text.splitlines() if pattern.match(line))


def cmd_check(args):
    entries, bad = load_entries()
    ok = True
    if bad:
        report_bad(bad)
        ok = False
    else:
        prs = sorted({e.pr for e in entries})
        print("✓ %d change file(s) under docs/changes/ parse: %d decision(s), each with a reason and a parity status."
              % (len(prs), len(entries)))

    # The frozen ledgers are closed. A branch that grows them is a branch
    # that didn't get the memo — and it will conflict with the next one that
    # didn't either, which is the whole thing this layout ends.
    base = args.base_ref
    head_dec = frozen_text(FROZEN_DECISIONS)
    head_led = frozen_text(FROZEN_LEDGER)
    base_dec = git_show(base, "docs/decisions.md")
    base_led = git_show(base, "docs/web-parity.md")
    if base_dec or base_led:
        added_dec = count_rows(head_dec, DECISION_ROW_RE) - count_rows(base_dec, DECISION_ROW_RE)
        added_led = count_rows(head_led, LEDGER_ROW_RE) - count_rows(base_led, LEDGER_ROW_RE)
        if added_dec > 0 or added_led > 0:
            ok = False
            print("✗ This branch adds %d row(s) to docs/decisions.md and %d to docs/web-parity.md."
                  % (max(added_dec, 0), max(added_led, 0)))
            print("  Both files are frozen as of 2026-10-19. New decisions go in docs/changes/<pr>.md —")
            print("  one file per PR, with ## Decision, ## Why and ## Web parity. See docs/changes/README.md.")
        else:
            print("✓ Frozen ledgers untouched (decisions %+d, parity %+d rows vs %s)." % (added_dec, added_led, base))
    else:
        print("· Could not read %s — skipping the frozen-ledger diff (shallow clone?)." % base)
    return 0 if ok else 1


def cmd_status(args):
    """Parity counts: the frozen ledger's rows (via parity-status.sh's rules) plus ours."""
    entries, bad = load_entries()
    counts = Counter(e.status for e in entries if e.status)
    print("Web parity since the cutover — %d decision(s) in docs/changes/" % len(entries))
    for key in STATUSES:
        if counts.get(key):
            print("  %-8s %4d" % (key, counts[key]))
    pending = counts.get("pending", 0)
    print("%d decision(s) not yet answered on the web." % pending if pending
          else "Nothing pending since the cutover.")
    if bad:
        print()
        report_bad(bad)
        return 1
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="write the assembled log and ledger")
    b.add_argument("--out", default=DEFAULT_OUT)
    b.set_defaults(fn=cmd_build)
    c = sub.add_parser("check", help="validate change files; fail if a frozen ledger grew")
    c.add_argument("base_ref", nargs="?", default="origin/main")
    c.set_defaults(fn=cmd_check)
    s = sub.add_parser("status", help="parity counts across docs/changes/")
    s.set_defaults(fn=cmd_status)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
