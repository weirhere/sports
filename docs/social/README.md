# Social graphics

Promo images built from the App Store screenshots in `docs/appstore/screenshots/`.
Black stage, one red accent, logos in color — the app's color budget holds.

## Launch thread

One graphic per tweet, all 1600 × 900 (rendered 3200 × 1800) so the thread
crops identically in the timeline.

| Tweet | File | What it shows |
|---|---|---|
| 1. "StatSide is college football, at a glance…" | `statside-landscape-1600x900.png` | Three devices — Scores, Rankings, Game detail |
| 2. "Kickoff is coming. Follow your teams now…" | `statside-02-follow.png` | Team page follow button + the Following section it feeds |
| 3. BUILT FOR SATURDAYS | `statside-03-saturdays.png` | The five bullets, Scores device alongside |
| 4. A WEEK, NOT A DATE | `statside-04-week.png` | The week strip, and the slate it controls |
| 5. RANKINGS AND DETAILS | `statside-05-rankings.png` | Rankings device with movement arrows, Game detail behind |
| 6. DESIGNED QUIET | `statside-06-quiet.png` | Typographic — the four things the app doesn't do |
| 7. "Free. Fast. One sport, done right." | `statside-07-closer.png` | Icon, wordmark, tagline, disclaimer |

Tweet 6 has no device on purpose. It's about absence.

## Other crops of the hero

Same composition as tweet 1, reshaped for feeds that aren't 16:9.

| File | Rendered size | Made for |
|---|---|---|
| `statside-square-1080.png` | 2160 × 2160 | Instagram feed, LinkedIn |
| `statside-portrait-1080x1350.png` | 2160 × 2700 | Instagram 4:5, the one that fills the most feed |

## Regenerating

Source is plain HTML/CSS in `src/`, rendered with headless Chromium at 2x.
Type is Inter (Inter Display for headlines) — install it locally first; without
it the render falls back to whatever sans the system has.

```sh
cd docs/social/src
CHROME=/path/to/chrome   # any Chromium/Chrome build

# every thread graphic is 1600×900
for f in 02-follow 03-saturdays 04-week 05-rankings 06-quiet 07-closer; do
  "$CHROME" --headless --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=2 --window-size=1600,900 \
    --screenshot="../statside-$f.png" \
    --virtual-time-budget=4000 "file://$PWD/$f.html"
done
```

The hero uses `landscape.html` at 1600,900, `square.html` at 1080,1080, and
`portrait.html` at 1080,1350. The window size must match the `.stage`
dimensions in each file's inline `<style>` block, or the render clips.

Shared styling lives in `src/social.css`; each file overrides the background
gradients and positions its own devices and crops.

## Notes

- The `.crop` blocks are windows onto a full screenshot: the `img` is scaled to
  the card width and offset with negative `top` to land on the region you want.
  Screenshots are 1320 × 2868, so `scale = card_width / 1320` and
  `top = -region_y * scale`. Change the screenshots and every offset moves.
- Device frames are driven by one number: `font-size` on `.phone` sets its
  width (`width: 1em`), and the bezel and radii are `em` fractions of it. The
  outer radius is `screen-radius + bezel`, so the curves stay concentric at any
  size. Don't switch the bezel back to a percentage — percentage padding
  resolves against the containing block, not the element, which pins the bezel
  to a fixed width while the radii scale.
- Absolute positioning inside `.content` can silently drop content in headless
  renders — keep copy in normal flow and let the flex column stack it.
- Screens are from Week 10 of the 2025 season with final poll data, so the
  graphics are dated to that slate. Reshoot the App Store screenshots and
  re-render to move them forward.
