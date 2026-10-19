#!/usr/bin/env python3
"""
Side-by-side before/after page for the component snapshots.

    scripts/ui-report.py                       changed PNGs vs HEAD → /tmp/ui-report/index.html
    scripts/ui-report.py --base main           …vs another ref
    scripts/ui-report.py --expected "The chips row sits 8pt under the title"
    scripts/ui-report.py --expected-file notes.md --out /tmp/ui-report
    scripts/ui-report.py --sim shot.png        add a simulator screenshot to the page

"Before" is the committed baseline (`git show <base>:<path>`), "after" is the
PNG in the working tree, so the page reads straight off a `--record` run
before anything is committed. Snapshots that didn't change are listed, not
shown. With Pillow installed each changed pair also gets a difference image
(changed pixels in magenta) and a changed-pixel percentage; without it the
pair stands on its own.

Nothing here is served or uploaded: it writes files under --out and prints
the path. Open it with `open /tmp/ui-report/index.html`.
"""

import argparse
import datetime as dt
import html
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAPSHOTS = "sportsTests/Snapshots/__Snapshots__"


def git(*args, binary=False):
    result = subprocess.run(["git", "-C", ROOT, *args], capture_output=True, check=False)
    if result.returncode != 0:
        return None
    return result.stdout if binary else result.stdout.decode().strip()


def working_pngs():
    found = []
    for base, _, files in os.walk(os.path.join(ROOT, SNAPSHOTS)):
        for name in files:
            if name.endswith(".png"):
                found.append(os.path.relpath(os.path.join(base, name), ROOT))
    return sorted(found)


def committed_pngs(ref):
    listed = git("ls-tree", "-r", "--name-only", ref, "--", SNAPSHOTS)
    return sorted(line for line in (listed or "").splitlines() if line.endswith(".png"))


def diff_images(before_path, after_path, out_path):
    """Magenta where the pixels differ. Returns the changed fraction, or
    None when Pillow isn't available or the sizes differ."""
    try:
        from PIL import Image, ImageChops
    except ImportError:
        return None
    before = Image.open(before_path).convert("RGBA")
    after = Image.open(after_path).convert("RGBA")
    if before.size != after.size:
        return None
    delta = ImageChops.difference(before, after).convert("L").point(lambda v: 255 if v else 0)
    changed = sum(1 for v in delta.getdata() if v)
    total = delta.size[0] * delta.size[1]
    faded = Image.blend(after, Image.new("RGBA", after.size, (255, 255, 255, 255)), 0.6)
    magenta = Image.new("RGBA", after.size, (255, 0, 200, 255))
    faded.paste(magenta, mask=delta)
    faded.save(out_path)
    return changed / total if total else 0.0


def label(rel):
    """`startersCard.football-iPhone17Pro-dark` out of the file name."""
    name = os.path.basename(rel)[: -len(".png")]
    test, _, variant = name.partition(".")
    return test, variant


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", default="HEAD", help="git ref holding the 'before' baselines (default HEAD)")
    parser.add_argument("--out", default="/tmp/ui-report", help="output directory (default /tmp/ui-report)")
    parser.add_argument("--title", default=None, help="page title")
    parser.add_argument("--expected", default=None, help="the expected visual outcome, written before the change")
    parser.add_argument("--expected-file", default=None, help="a file holding the expected outcome")
    parser.add_argument("--sim", action="append", default=[], metavar="PNG",
                        help="a simulator screenshot to show under the pairs (repeatable)")
    args = parser.parse_args()

    expected = args.expected
    if args.expected_file:
        with open(args.expected_file, encoding="utf-8") as handle:
            expected = handle.read()

    out = os.path.abspath(args.out)
    images = os.path.join(out, "img")
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(images)

    current = working_pngs()
    committed = committed_pngs(args.base)
    every = sorted(set(current) | set(committed))

    rows = []
    unchanged = []
    for rel in every:
        after_path = os.path.join(ROOT, rel) if rel in current else None
        before_bytes = git("show", f"{args.base}:{rel}", binary=True) if rel in committed else None
        after_bytes = open(after_path, "rb").read() if after_path else None
        if before_bytes is not None and after_bytes is not None and before_bytes == after_bytes:
            unchanged.append(rel)
            continue
        test, variant = label(rel)
        slug = f"{test}.{variant}"
        before_file = after_file = diff_file = None
        if before_bytes is not None:
            before_file = f"img/{slug}.before.png"
            with open(os.path.join(out, before_file), "wb") as handle:
                handle.write(before_bytes)
        if after_bytes is not None:
            after_file = f"img/{slug}.after.png"
            shutil.copyfile(after_path, os.path.join(out, after_file))
        fraction = None
        if before_file and after_file:
            diff_file = f"img/{slug}.diff.png"
            fraction = diff_images(os.path.join(out, before_file), os.path.join(out, after_file),
                                   os.path.join(out, diff_file))
            if fraction is None:
                diff_file = None
        status = "changed" if before_file and after_file else ("added" if after_file else "removed")
        rows.append(dict(test=test, variant=variant, before=before_file, after=after_file,
                         diff=diff_file, fraction=fraction, status=status))

    sims = []
    for index, path in enumerate(args.sim):
        if not os.path.isfile(path):
            print(f"warning: no such screenshot {path}", file=sys.stderr)
            continue
        name = f"img/sim-{index}-{os.path.basename(path)}"
        shutil.copyfile(path, os.path.join(out, name))
        sims.append((os.path.basename(path), name))

    branch = git("rev-parse", "--abbrev-ref", "HEAD") or "?"
    head = git("rev-parse", "--short", "HEAD") or "?"
    title = args.title or f"UI report — {branch}"
    when = dt.datetime.now().strftime("%Y-%m-%d %H:%M")

    def esc(text):
        return html.escape(text or "")

    parts = [f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>{esc(title)}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {{ --bg:#fff; --fg:#1a1a1a; --muted:#6b6b6b; --line:#e0e0e0; --card:#f7f7f7; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#111; --fg:#f2f2f2; --muted:#9a9a9a; --line:#333; --card:#1b1b1b; }} }}
body {{ margin:0; padding:24px; font:14px/1.45 -apple-system, system-ui, sans-serif; background:var(--bg); color:var(--fg); }}
h1 {{ font-size:20px; margin:0 0 4px; }} h2 {{ font-size:15px; margin:32px 0 8px; }}
.meta {{ color:var(--muted); margin-bottom:16px; }}
.expected {{ background:var(--card); border:1px solid var(--line); border-radius:8px; padding:12px 16px; white-space:pre-wrap; max-width:820px; }}
.pair {{ border-top:1px solid var(--line); padding:16px 0; }}
.pair .name {{ font-weight:600; }} .pair .tag {{ color:var(--muted); font-weight:400; margin-left:8px; }}
.cols {{ display:flex; gap:16px; flex-wrap:wrap; align-items:flex-start; margin-top:8px; }}
.col {{ flex:1 1 300px; max-width:460px; }}
.col .cap {{ color:var(--muted); font-size:12px; margin-bottom:4px; }}
.col img {{ width:100%; height:auto; display:block; border:1px solid var(--line); background:
  repeating-conic-gradient(#8882 0 25%, transparent 0 50%) 0 0 / 16px 16px; }}
details {{ margin-top:24px; color:var(--muted); }} details li {{ font-family:ui-monospace, monospace; font-size:12px; }}
.sim img {{ max-width:320px; border:1px solid var(--line); border-radius:12px; }}
</style></head><body>
<h1>{esc(title)}</h1>
<div class="meta">{esc(when)} · after = working tree · before = {esc(args.base)} ({esc(head)}) · {len(rows)} changed, {len(unchanged)} unchanged</div>
"""]
    if expected:
        parts.append(f"<h2>Expected outcome</h2><div class=\"expected\">{esc(expected.strip())}</div>")

    parts.append("<h2>Changed snapshots</h2>")
    if not rows:
        parts.append("<p class=\"meta\">No snapshot differs from the baseline.</p>")
    for row in rows:
        tag = row["status"]
        if row["fraction"] is not None:
            tag += f" · {row['fraction'] * 100:.2f}% of pixels"
        parts.append(f"<div class=\"pair\"><div class=\"name\">{esc(row['test'])} <span class=\"tag\">"
                     f"{esc(row['variant'])} · {esc(tag)}</span></div><div class=\"cols\">")
        for cap, key in (("Before", "before"), ("After", "after"), ("Difference", "diff")):
            if row[key]:
                parts.append(f"<div class=\"col\"><div class=\"cap\">{cap}</div><img src=\"{row[key]}\" alt=\"{cap}\"></div>")
        parts.append("</div></div>")

    if sims:
        parts.append("<h2>Simulator</h2><div class=\"cols sim\">")
        for name, src in sims:
            parts.append(f"<div class=\"col\"><div class=\"cap\">{esc(name)}</div><img src=\"{src}\" alt=\"{esc(name)}\"></div>")
        parts.append("</div>")

    parts.append("<details><summary>Unchanged snapshots</summary><ul>")
    parts.extend(f"<li>{esc(os.path.basename(rel))}</li>" for rel in unchanged)
    parts.append("</ul></details></body></html>")

    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(parts))
    print(os.path.join(out, "index.html"))
    print(f"{len(rows)} changed, {len(unchanged)} unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
