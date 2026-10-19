# The 14s spot

`StatSide-14s-horizontal-1920x1080.mp4` and `StatSide-14s-vertical-1080x1920.mp4`,
rendered from `src/video/scene.html`. Rebuilt 2026-10-19 after the first cut
drew 2 notes: make it more stylized, and put the words in human words. The
same day, Andy asked for the screens in a phone like Carlos's, so the flat
screen on a white stage became a 3D device on a dark one.

## The 2 references

Andy pointed at these, and the new cut copies their grammar rather than their
look:

- **Cole, @colderoshay on X (2026-10-16).** A 10s screen recording of a Chrome
  extension. The UI sits on a near-white stage, tilted a few degrees in
  perspective. Rows pop in 1 at a time. The camera dollies out slowly and, in
  the last 3 seconds, an icon and a 3-line card slide in on the right: the
  name, 1 line of what it does, "for Chrome". No voice, no music cue, no
  feature list.
- **Carlos, @carlosmlon on Threads (2026-10-18).** A 3D iPhone tilted hard,
  the camera in macro on the screen, a dark workout app building in
  micro-animations. Same idea, closer lens.

What they share: the product is the picture, the words are 1 short card, and
nothing in frame is an ad for anything. The cut takes Cole's structure (build,
pull back, title card) and Carlos's picture (a real phone, close, tilted
hard, dark stage).

## Storyboard

Both cuts run the same 14 seconds. Times are the keyframes in `scene.html`.

| Time | Picture | Words |
|---|---|---|
| 0.0 | Dark gray stage with 1 soft key light. The phone in macro, tilted hard (rotateX 48°, rotateY -10°, rotateZ -32°), camera close on its top-left corner so the Dynamic Island and the rail fill the frame. | |
| 0.35–4.2 | The screen builds in 9 slices, top to bottom: header and day strip, then the Following card's header and 3 rows, then the ACC card's. Each rises 44px and fades in over 0.75s, 0.26s apart. | |
| 1.1–5.1 | | **opens on the teams you follow** |
| 5.35–5.95 | A tap ring on the Georgia row. | |
| 5.8–6.55 | The game page pushes in from the right; the Scores screen slides 28% left and dims 10%, iOS style. | |
| 6.6–10.2 | Camera drifts, almost still; the phone eases toward upright (rotateX 28°, rotateZ -16°). | **tap a game, get the whole story** |
| 10.2–11.9 | Pull back to centre-left; the phone settles to a mild tilt (rotateX 10°, rotateY 14°, rotateZ -4°). | |
| 10.7–12.2 | | Icon, **StatSide**, **Your teams, first.**, *for iPhone*, each 0.16s after the last. |
| 14.0 | Hold. | |

Horizontal: the phone runs diagonally through the left two-thirds, the copy
has the right column. Vertical: the phone fills the frame from y≈400 down and
the copy owns the top band, above Instagram's chrome.

## The phone

There is no 3D renderer here, so the device is built in CSS 3D and it holds up
at these angles:

- **Body.** 29 copies of the same rounded rectangle, each 1/28 of the body's
  thickness further back (`translateZ`), so a steep tilt shows a solid rail.
  The front copy is the bezel (near-black, a 1.5px light chamfer ring); the
  rest wear a graphite gradient; the back one is matte. Thickness is 11.5% of
  the width, the bezel 2.4%, the body radius concentric with the screen's.
- **Screen.** Inset by the bezel, the slices and the game page inside it, a
  diagonal glare pass on top and the Dynamic Island (32% of the screen's
  width, at the iPhone's position; the masters' status bars leave that spot
  empty).
- **Buttons.** Action, volume up and down on the left, power on the right:
  thin boxes rotated 90° about Y so they sit flush in the rail.
- **Shadow.** A blurred black copy of the body 60px behind it, offset down
  and right.

Graphite rather than Carlos's orange: the body is chrome around the app's
screen, and the stage is the thread graphics' black, so the only color in
frame stays the logos and the icon's dot. The body colors are the `.shell`
gradients in `scene.html` if that ever changes.

## The copy, before and after

The first cut carried the pitch the drafts in `launch-copy-video.md` repeat on
every platform: "your teams at the top, refreshed every second, any game 1 tap
from the full story", plus a league list and "Free on iPhone". The notes said
it read like an ad. In this cut the picture carries the features and the words
are what a person would type:

| Beat | Before | Now |
|---|---|---|
| Following card builds | your teams at the top | opens on the teams you follow |
| Game page pushes in | any game 1 tap from the full story | tap a game, get the whole story |
| Closer | StatSide · Football, basketball and hockey · Free on iPhone | StatSide · Your teams, first. · for iPhone |

Lowercase captions on purpose: they read as typed, like Cole's post. The
closer is sentence case because it's the only line that is a title.

Dropped on purpose: "refreshed every second". The masters are all finals (shot
2026-09-05 before kickoff), so there's no live row to show it on, and a caption
the picture can't back up is the ad voice coming back. When a live-game master
exists, that beat is 1 more slice and a pulsing dot.

The league names and the price stay out too, for the same reason as the App
Store frames (the 4.1(a) and 2.3.7 rejections). These are organic posts where
both would be allowed; they just aren't needed.

## Rendering

The scene is deterministic: `window.seek(t)` sets every transform from `t`, so
a render at 30 or 60fps is the same film, and a browser can scrub it (open
`scene.html`, space plays, arrows step 0.1s; add `?v` for the vertical cut).

```sh
cd docs/social/src/video
node render.cjs h     # 1920x1080 → ../../StatSide-14s-horizontal-1920x1080.mp4
node render.cjs v     # 1080x1920 → ../../StatSide-14s-vertical-1080x1920.mp4
node render.cjs h --preview   # 7 stills into preview/ to check a change
```

`render.cjs` drives headless Chromium through Playwright (`npm i -g
playwright`, or point `PLAYWRIGHT_MODULE` at an install), screenshots each
frame as JPEG and hands them to ffmpeg (libx264, crf 18, 60fps). 840 frames
take a few minutes. Inter has to be installed system-wide here; this scene
doesn't use `social.css`'s absolute-path `@font-face`.

The stage is dark gray (`#141416`) with a neutral radial key light behind the
device. The monochrome rule holds: the only color in frame is the
screenshots' own, which is logos and the icon's red dot. The first cut of the
day (commit e47575b) was the same storyboard on a near-white stage with a
flat, frameless screen, if a lighter version is ever wanted.

## Masters

- `docs/appstore/screenshots/01-scores.png`, sliced at y = 0, 526, 652, 947,
  1242, 1560, 1686, 1981, 2276 (card edges and row dividers, found by scanning
  a column for white rows and gray dividers).
- `docs/appstore/screenshots/02-game-detail.png`, whole.
- `sports/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

Reshoot the masters and the slice table in `scene.html` has to be re-measured;
a row divider that moves 20px shows as a seam mid-build.
