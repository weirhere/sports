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

## Story set (9:16)

The same seven beats at 1080 × 1920 (rendered 2160 × 3840), so the thread can
run as a Story sequence in the same order.

| Frame | File |
|---|---|
| 1 | `statside-story-1080x1920.png` |
| 2 | `statside-story-02-follow.png` |
| 3 | `statside-story-03-saturdays.png` |
| 4 | `statside-story-04-week.png` |
| 5 | `statside-story-05-rankings.png` |
| 6 | `statside-story-06-quiet.png` |
| 7 | `statside-story-07-closer.png` |

Sources are `src/story.html` and `src/story-*.html`, all rendered at 1080,1920.
Shared story styling is the `.stage9` block in `social.css` — note that
`.stage9 .head` outranks a bare `.head`, so per-file overrides need the
`.stage9` prefix or they silently lose.

## Other crops of the hero

Same composition as tweet 1, reshaped for feeds that aren't 16:9.

| File | Rendered size | Made for |
|---|---|---|
| `statside-square-1080.png` | 2160 × 2160 | Instagram feed, LinkedIn |
| `statside-portrait-1080x1350.png` | 2160 × 2700 | Instagram 4:5, the one that fills the most feed |
| `statside-story-1080x1920.png` | 2160 × 3840 | Instagram/Facebook Stories, 9:16 |

The story version keeps every word inside the middle band, because Instagram's
own chrome — profile header up top, reply bar at the bottom — covers roughly
the top and bottom 250px (500px on the 2x asset). Only the devices run under
it. Instagram downsamples to 1080 × 1920 on upload; the 2x master is there for
headroom.

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

The hero uses `landscape.html` at 1600,900, `square.html` at 1080,1080,
`portrait.html` at 1080,1350, and `story.html` at 1080,1920. The window size must match the `.stage`
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

## App Store screenshot set (1284 × 2778)

The same seven designs re-rendered at the size App Store Connect accepts for
the 6.5" slot, in `docs/appstore/screenshots-marketing-1284x2778/`.

This is a reflow, not a resize. A story is 1080 × 1920 (ratio 0.5625); the App
Store slot is 1284 × 2778 (0.4622) — taller and proportionally narrower. Scaling
the raster would either squash the artwork or slice the bleeding devices off
flat with black beneath them.

Sources are `src/as-*.html`: each one is its `story-*.html` counterpart plus a
trailing `<style>` block that overrides the stage and the vertical positions.
The trick is the stage becomes 1080 × 2337 with `zoom: 1.18889` — 2337 is
2778 ÷ 1.18889, so the layout stays in familiar 1080-wide coordinates and zoom
carries it to the exact pixel size Apple wants. Render at
`--window-size=1284,2778 --force-device-scale-factor=1`; the output must be
exactly 1284 × 2778 or App Store Connect rejects it.

The Instagram safe-zone insets are pulled back in these, since the App Store
draws no chrome over the image.
