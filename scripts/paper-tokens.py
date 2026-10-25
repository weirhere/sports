#!/usr/bin/env python3
"""Export the iOS design tokens as Paper design tokens.

Reads StatSideShared/Theme/Theme.swift and SurfaceColors.swift (the only
named token sources in the app) and prints a JSON array of Paper
`create_tokens` entries, plus a per-category count on stderr.

Naming: the Swift path in kebab case — `Color.bgPrimary` becomes
`--color-bg-primary`, `SurfaceColors.turfAlternate` becomes
`--surface-colors-turf-alternate`. Paper names allow only [A-Za-z0-9_-] and
are stored lowercased, so `.`, `/` and camelCase can't survive. Paper tokens have no modes,
so a scheme-adaptive color's light value takes the plain name and its dark
value the same name plus `-dark`. A `Font` token is size + weight + Dynamic
Type style in one; Paper has no composite type, so it splits into
`--font-<name>-size` and `--font-<name>-weight`, with the text style and
monospaced digits recorded in the description.

Usage: scripts/paper-tokens.py [--out tokens.json]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = ROOT / "StatSideShared/Theme/Theme.swift"
SURFACE = ROOT / "StatSideShared/Theme/SurfaceColors.swift"

WEIGHTS = {"regular": 400, "medium": 500, "semibold": 600, "bold": 700, "heavy": 800}
NUM = r"([0-9.]+(?:\s*/\s*[0-9.]+)?)"


def kebab(path):
    """`SurfaceColors.turfAlternate` -> `surface-colors-turf-alternate`.

    Paper lowercases token names, so camelCase can't survive; kebab keeps the
    word breaks and maps back to the Swift name one to one.
    """
    return re.sub(r"(?<=[a-z0-9])([A-Z])", r"-\1", path.replace(".", "-")).lower()


def num(expr):
    a, _, b = expr.partition("/")
    return float(a) / float(b) if b else float(a)


def css(r, g, b, a=1.0):
    r, g, b = (int(c * 255 + 0.5) for c in (r, g, b))
    if a >= 1:
        return f"#{r:02x}{g:02x}{b:02x}"
    return f"rgba({r}, {g}, {b}, {a:g})"


def uicolors(chunk):
    """Every UIColor literal in source order, as CSS strings."""
    out = []
    pat = re.compile(
        rf"UIColor\(red: {NUM}, green: {NUM}, blue: {NUM}, alpha: {NUM}\)"
        rf"|UIColor\(white: {NUM}, alpha: {NUM}\)|(?<![\w.])\.clear\b"
    )
    for m in pat.finditer(chunk):
        if m.group(1):
            out.append(css(*(num(m.group(i)) for i in range(1, 5))))
        elif m.group(5):
            w = num(m.group(5))
            out.append(css(w, w, w, num(m.group(6))))
        else:
            out.append("transparent")
    return out


def doc(lines):
    text = " ".join(l.strip().removeprefix("///").strip() for l in lines)
    return re.sub(r"\s+", " ", text).strip()


def members(source, kind):
    """(name, doc, body) for each `static let|var` in source order."""
    out, docs = [], []
    lines = source.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("///"):
            docs.append(line)
        elif m := re.match(rf"(?:nonisolated )?static (?:let|var) (\w+)\b", line):
            body = [lines[i]]
            depth = lines[i].count("(") - lines[i].count(")") + lines[i].count("{") - lines[i].count("}")
            while depth > 0:
                i += 1
                body.append(lines[i])
                depth += lines[i].count("(") - lines[i].count(")") + lines[i].count("{") - lines[i].count("}")
            out.append((m.group(1), doc(docs), "\n".join(body)))
            docs = []
        elif not line.startswith("//"):
            docs = []
        i += 1
    return out


def block(source, header):
    start = source.index(header)
    depth, j = 0, source.index("{", start)
    for k in range(j, len(source)):
        depth += {"{": 1, "}": -1}.get(source[k], 0)
        if depth == 0:
            return source[j:k + 1]
    raise ValueError(header)


def describe(path, text):
    text = f"{path}. {text}" if text else f"{path}."
    return text if len(text) <= 1024 else text[:1021] + "..."


def color_tokens(prefix, source_name, body_source, aliases):
    tokens, skipped = [], []
    for name, text, body in members(body_source, "color"):
        path = f"{prefix}.{name}"
        light = dark = None
        if m := re.search(rf"lightWhite: {NUM}, darkWhite: {NUM}", body):
            lw, dw = num(m.group(1)), num(m.group(2))
            light, dark = css(lw, lw, lw), css(dw, dw, dw)
        elif m := re.search(r"dynamic\(light: \(([^)]*)\),\s*dark: \(([^)]*)\)\)", body):
            light = css(*(float(x) for x in m.group(1).split(",")))
            dark = css(*(float(x) for x in m.group(2).split(",")))
        elif m := re.search(rf"UIColor\(white: traits\.userInterfaceStyle == \.dark \? {NUM} : {NUM}, alpha: {NUM}\)", body):
            d, l, a = num(m.group(1)), num(m.group(2)), num(m.group(3))
            light, dark = css(l, l, l, a), css(d, d, d, a)
        elif "userInterfaceStyle == .dark" in body:
            found = uicolors(body)
            if len(found) == 2:
                dark, light = found  # `== .dark ? DARK : LIGHT`
        elif m := re.search(rf"Color\(white: {NUM}\)", body):
            w = num(m.group(1))
            light = css(w, w, w)
        elif m := re.search(rf"Color\(red: {NUM}, green: {NUM}, blue: {NUM}\)", body):
            light = css(*(num(m.group(i)) for i in range(1, 4)))
        elif re.search(r"= Color\.white\b", body):
            light = "#ffffff"
        elif m := re.search(r"= (?:Color\.)?(\w+)\s*$", body.strip()):
            target = aliases.get(m.group(1))
            if target:
                tokens.append(dict(type="color", name=f"--{kebab(prefix + '.' + name)}", value=f"var(--{target})",
                                   description=describe(path, text)))
                # Kept only if the target has a dark value; see main().
                tokens.append(dict(type="color", name=f"--{kebab(prefix + '.' + name)}-dark",
                                   value=f"var(--{target}-dark)",
                                   description=describe(path + " (dark)", "")))
                continue
        if light is None:
            if "->" not in body:
                skipped.append((path, "value not a literal the exporter can map"))
            continue
        tokens.append(dict(type="color", name=f"--{kebab(prefix + '.' + name)}", value=light, description=describe(path, text)))
        if dark is not None:
            tokens.append(dict(type="color", name=f"--{kebab(prefix + '.' + name)}-dark", value=dark,
                               description=describe(path + " (dark)", "")))
    return tokens, skipped


def main():
    theme = THEME.read_text()
    surface = SURFACE.read_text()
    color_body = block(theme, "extension Color {")
    surface_body = block(surface, "enum SurfaceColors {")
    # Strip nested types/functions out of SurfaceColors: they map leagues to
    # paints, they aren't values.
    surface_flat = re.sub(r"(?:\n    ///[^\n]*)*\n    (?:struct|static func)[^\n]*\{.*?\n    \}\n", "\n", surface_body, flags=re.S)

    color_names = [n for n, _, _ in members(color_body, "color")]
    aliases = {n: kebab(f"Color.{n}") for n in color_names}

    tokens, skipped = color_tokens("Color", "Theme.swift", color_body, aliases)
    st, ss = color_tokens("SurfaceColors", "SurfaceColors.swift", surface_flat, aliases)
    tokens += st
    skipped += ss
    # An alias's dark twin exists only when what it points at has one.
    names = {t["name"] for t in tokens}
    tokens = [t for t in tokens if not str(t["value"]).startswith("var(")
              or t["value"][4:-1] in names]

    for name, _, body in members(block(theme, "enum Spacing {"), "spacing"):
        if m := re.search(rf"CGFloat = {NUM}", body):
            tokens.append(dict(type="spacing", name=f"--{kebab('Spacing.' + name)}", value=f"{num(m.group(1)):g}px",
                               description=f"Spacing.{name}."))

    for name, text, body in members(block(theme, "extension Font {"), "font"):
        m = re.search(rf"scaled\({NUM}, \.(\w+), relativeTo: \.(\w+)\)", body)
        if not m:
            continue
        mono = " Monospaced digits." if "monospacedDigit" in body else ""
        meta = f"Scales with Dynamic Type relative to .{m.group(3)}.{mono}"
        desc = describe(f"Font.{name}", f"{text} {meta}".strip())
        tokens.append(dict(type="fontSize", name=f"--{kebab('Font.' + name)}-size", value=f"{num(m.group(1)):g}px", description=desc))
        tokens.append(dict(type="fontWeight", name=f"--{kebab('Font.' + name)}-weight", value=WEIGHTS[m.group(2)], description=desc))

    out = json.dumps(tokens, indent=1, ensure_ascii=False)
    if "--out" in sys.argv:
        Path(sys.argv[sys.argv.index("--out") + 1]).write_text(out)
    else:
        print(out)
    counts = {}
    for t in tokens:
        key = t["type"] + (" (alias)" if str(t["value"]).startswith("var(") else "")
        key += " dark" if t["name"].endswith("-dark") else ""
        counts[key] = counts.get(key, 0) + 1
    print(json.dumps({"total": len(tokens), "counts": counts, "skipped": skipped}, indent=1), file=sys.stderr)


if __name__ == "__main__":
    main()
