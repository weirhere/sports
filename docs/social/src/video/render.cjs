// Renders scene.html to frames with headless Chromium, then encodes with
// ffmpeg. Usage:
//   node render.cjs h            horizontal 1920x1080 → StatSide-14s-horizontal-1920x1080.mp4
//   node render.cjs v            vertical   1080x1920 → StatSide-14s-vertical-1080x1920.mp4
//   node render.cjs h --preview  a handful of PNG stills into preview/ instead
// Env: FPS (default 60), OUT (default ../../, i.e. docs/social/).
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const mode = process.argv[2] === 'v' ? 'v' : 'h';
const preview = process.argv.includes('--preview');
const FPS = Number(process.env.FPS || 60);
const W = mode === 'h' ? 1920 : 1080, H = mode === 'h' ? 1080 : 1920;
const name = mode === 'h' ? 'StatSide-14s-horizontal-1920x1080' : 'StatSide-14s-vertical-1080x1920';
const outDir = path.resolve(__dirname, process.env.OUT || '../../');
const framesDir = path.join(process.env.FRAMES || path.join(__dirname, 'frames'), mode);

(async () => {
  const browser = await chromium.launch({ args: ['--font-render-hinting=none', '--disable-lcd-text'] });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const url = 'file://' + path.join(__dirname, 'scene.html') + (mode === 'v' ? '?v' : '');
  await page.goto(url, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const duration = await page.evaluate(() => window.DURATION);

  if (preview) {
    const dir = path.join(__dirname, 'preview'); fs.mkdirSync(dir, { recursive: true });
    const times = (process.env.TIMES || '0.4,2.2,4.6,5.9,7.4,10.9,13.5').split(',').map(Number);
    for (const t of times) {
      await page.evaluate(t => window.seek(t), t);
      await page.screenshot({ path: path.join(dir, `${mode}-${t.toFixed(1)}.png`), type: 'png' });
    }
    await browser.close();
    console.log('previews in', dir);
    return;
  }

  fs.rmSync(framesDir, { recursive: true, force: true });
  fs.mkdirSync(framesDir, { recursive: true });
  const n = Math.round(duration * FPS);
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    await page.evaluate(t => window.seek(t), i / FPS);
    await page.screenshot({ path: path.join(framesDir, String(i).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 96 });
    if (i % 120 === 0) console.log(`frame ${i}/${n}`);
  }
  await browser.close();
  console.log(`rendered ${n} frames in ${((Date.now() - t0) / 1000).toFixed(0)}s`);

  fs.mkdirSync(outDir, { recursive: true });
  const out = path.join(outDir, name + '.mp4');
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-framerate', String(FPS), '-i', path.join(framesDir, '%05d.jpg'),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'slow', '-movflags', '+faststart', out], { stdio: 'inherit' });
  fs.rmSync(framesDir, { recursive: true, force: true });
  console.log('wrote', out);
})();
