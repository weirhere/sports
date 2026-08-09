# Social graphics

Promo images built from the App Store screenshots in `docs/appstore/screenshots/`.
Black stage, three device mockups, one red accent — the app's color budget holds.

| File | Rendered size | Made for |
|---|---|---|
| `statside-square-1080.png` | 2160 × 2160 (1080 @2x) | Instagram feed, LinkedIn |
| `statside-portrait-1080x1350.png` | 2160 × 2700 (1080 × 1350 @2x) | Instagram 4:5, the one that fills the most feed |
| `statside-landscape-1600x900.png` | 3200 × 1800 (1600 × 900 @2x) | X, LinkedIn, Open Graph |

Screens shown: Scores (hero), Rankings (left), Game detail (right).

## Regenerating

Source is plain HTML/CSS in `src/`, rendered with headless Chromium at 2x.
The type is Inter (Inter Display for the headline) — install it locally first;
without it the render falls back to whatever sans the system has.

```sh
cd docs/social/src
CHROME=/path/to/chrome   # any Chromium/Chrome build
"$CHROME" --headless --hide-scrollbars --allow-file-access-from-files \
  --force-device-scale-factor=2 --window-size=1080,1080 \
  --screenshot=../statside-square-1080.png \
  --virtual-time-budget=4000 "file://$PWD/square.html"
```

Swap `--window-size` and the html file for the other two: `portrait.html`
at 1080,1350 and `landscape.html` at 1600,900. The window size must match the
`.stage` dimensions in each file's inline `<style>` block.

Copy changes live in the `.headline`, `.sub`, and `.pill` elements — all three
files carry the same wording, so edit all three together.
