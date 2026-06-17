// Generates marketing screenshots for the App Store and Play Store.
//
// 1. Drives the web build (served on :8099) to capture raw app screens.
// 2. Composes each into a captioned marketing frame (parchment background,
//    Playfair/Space Mono caption, the screenshot as a rounded device card),
//    rendered at exact store pixel sizes.
//
// Output: ../store/appstore/*.png (1290x2796, Apple 6.7")
//         ../store/playstore/*.png (1080x1920)

import { chromium } from 'playwright';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const APP = 'http://localhost:8099/';
mkdirSync('../store/appstore', { recursive: true });
mkdirSync('../store/playstore', { recursive: true });

const playfair = readFileSync('../app/assets/fonts/PlayfairDisplay.ttf').toString('base64');
const mono = readFileSync('../app/assets/fonts/SpaceMono-Regular.ttf').toString('base64');

const SIZES = [
  { dir: '../store/appstore', W: 1290, H: 2796 },
  { dir: '../store/playstore', W: 1080, H: 1920 },
];

const b = await chromium.launch({ headless: true });

// ---- 1. capture raw app screens ----
const W = 390, H = 844;
const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
const page = await ctx.newPage();
const tap = async (x, y, d = 1100) => { await page.touchscreen.tap(x, y); await page.waitForTimeout(d); };
const settle = async () => {
  await page.waitForTimeout(4500);
  await page.setViewportSize({ width: W, height: H + 2 }); await page.waitForTimeout(400);
  await page.setViewportSize({ width: W, height: H });
  await page.evaluate(() => window.dispatchEvent(new Event('resize')));
  await page.waitForTimeout(2000);
};
const raw = async () => (await page.screenshot()).toString('base64');

await page.goto(APP, { waitUntil: 'load' });
await settle();

const shots = [];
// 1 — Library grid
shots.push({ img: await raw(), eyebrow: 'BIBLIOTHÈQUE', title: 'Tous vos recueils,\nhors‑ligne' });
// 2 — Reader
await tap(110, 330); await tap(195, 360);
shots.push({ img: await raw(), eyebrow: 'LECTURE', title: 'Comme un\ncantique imprimé' });
// 3 — Live share: the EN DIRECT follower view (needs a host running; the URL is
//     written to /tmp/indirimbo_host.txt by tools/share_host.dart).
try {
  const ws = readFileSync('/tmp/indirimbo_host.txt', 'utf8').trim();
  const fctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  const fp = await fctx.newPage();
  await fp.goto(`${APP}?join=${encodeURIComponent(ws)}`, { waitUntil: 'load' });
  await fp.waitForTimeout(5500);
  await fp.setViewportSize({ width: W, height: H + 2 }); await fp.waitForTimeout(400);
  await fp.setViewportSize({ width: W, height: H });
  await fp.evaluate(() => window.dispatchEvent(new Event('resize')));
  await fp.waitForTimeout(2500);
  shots.push({ img: (await fp.screenshot()).toString('base64'), eyebrow: 'PARTAGE EN DIRECT', title: 'Chantez\nensemble' });
  await fctx.close();
} catch (e) {
  console.log('share/follower shot skipped:', e.message);
}
// 4 — Settings: font pairings
await tap(341, 805);
await page.mouse.move(195, 430); await page.mouse.wheel(0, 720); await page.waitForTimeout(900);
shots.push({ img: await raw(), eyebrow: 'POLICES', title: 'Choisissez\nvotre style' });
// 5 — Library as a list
await tap(49, 805);
await tap(356, 190, 900); // list toggle
shots.push({ img: await raw(), eyebrow: '17 RECUEILS', title: '4 langues,\nune appli' });

await ctx.close();

// ---- 2. compose marketing frames ----
function frameHtml(img, eyebrow, title) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face{font-family:'PF';src:url(data:font/ttf;base64,${playfair}) format('truetype');}
    @font-face{font-family:'MN';src:url(data:font/ttf;base64,${mono}) format('truetype');}
    *{margin:0;padding:0;box-sizing:border-box}
    html,body{width:100%;height:100%}
    body{display:flex;flex-direction:column;align-items:center;
      background:linear-gradient(165deg,#EFE9DC 0%,#E6DAC2 100%);overflow:hidden}
    .eyebrow{font-family:'MN',monospace;color:#9E4A2C;letter-spacing:.45vw;
      font-weight:700;font-size:2.3vw;margin-top:7.5vh}
    .title{font-family:'PF',serif;color:#23201A;font-weight:700;
      font-size:7vw;line-height:1.08;text-align:center;margin-top:1.6vh;
      padding:0 7vw;white-space:pre-line}
    .device{margin-top:4.2vh;height:70vh;border-radius:4vw;overflow:hidden;
      box-shadow:0 1.6vw 5vw rgba(40,30,15,.30);border:.35vw solid rgba(0,0,0,.07)}
    .device img{height:100%;display:block}
  </style></head><body>
    <div class="eyebrow">${eyebrow}</div>
    <div class="title">${title}</div>
    <div class="device"><img src="data:image/png;base64,${img}"/></div>
  </body></html>`;
}

const names = ['01-library', '02-reader', '03-share', '04-fonts', '05-languages'];
for (const { dir, W: sw, H: sh } of SIZES) {
  const cc = await b.newContext({ viewport: { width: sw, height: sh }, deviceScaleFactor: 1 });
  const pp = await cc.newPage();
  for (let i = 0; i < shots.length; i++) {
    await pp.setContent(frameHtml(shots[i].img, shots[i].eyebrow, shots[i].title), { waitUntil: 'load' });
    await pp.waitForTimeout(250);
    await pp.screenshot({ path: `${dir}/${names[i]}.png` });
    console.log('wrote', `${dir}/${names[i]}.png`);
  }
  await cc.close();
}

await b.close();
console.log('DONE');
