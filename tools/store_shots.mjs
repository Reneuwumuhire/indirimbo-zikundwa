// Generates marketing screenshots for the App Store and Play Store, in French
// and English.
//
// For each language it drives the web build (served on :8099), switches the app
// language (EN), captures key screens, and composes each into a captioned
// parchment marketing frame at exact store sizes.
//
// Output: ../store/{appstore,playstore}/{fr,en}/NN-*.png
// Requires a running live-share host (tools/share_host.dart) for the share shot.

import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';

const APP = 'http://localhost:8099/';
const playfair = readFileSync('../app/assets/fonts/PlayfairDisplay.ttf').toString('base64');
const mono = readFileSync('../app/assets/fonts/SpaceMono-Regular.ttf').toString('base64');

const SIZES = [
  { store: 'appstore', W: 1290, H: 2796 },
  { store: 'playstore', W: 1080, H: 1920 },
];

const CAPTIONS = {
  fr: [
    ['BIBLIOTHÈQUE', 'Tous vos recueils,\nhors‑ligne'],
    ['LECTURE', 'Comme un\ncantique imprimé'],
    ['PARTAGE EN DIRECT', 'Chantez\nensemble'],
    ['POLICES', 'Choisissez\nvotre style'],
    ['17 RECUEILS', '4 langues,\nune appli'],
  ],
  en: [
    ['LIBRARY', 'All your hymnals,\noffline'],
    ['READING', 'Reads like a\nprinted hymnal'],
    ['LIVE SHARE', 'Sing\ntogether'],
    ['FONTS', 'Choose\nyour style'],
    ['17 BOOKS', '4 languages,\none app'],
  ],
};
const NAMES = ['01-library', '02-reader', '03-share', '04-fonts', '05-languages'];

const b = await chromium.launch({ headless: true });
const W = 390, H = 844;

async function settle(p) {
  await p.waitForTimeout(4500);
  await p.setViewportSize({ width: W, height: H + 2 }); await p.waitForTimeout(400);
  await p.setViewportSize({ width: W, height: H });
  await p.evaluate(() => window.dispatchEvent(new Event('resize')));
  await p.waitForTimeout(2000);
}

async function captureRaw(lang) {
  const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  const p = await ctx.newPage();
  const tap = async (x, y, d = 1100) => { await p.touchscreen.tap(x, y); await p.waitForTimeout(d); };
  await p.goto(APP, { waitUntil: 'load' });
  await settle(p);

  if (lang === 'en') {
    await tap(341, 805);     // Settings
    await tap(193, 129);     // English chip
    await tap(49, 805, 1200); // back to Books
    await settle(p);
  }

  const raw = async () => (await p.screenshot()).toString('base64');
  const shots = [];
  shots.push(await raw());                         // 1 library
  await tap(110, 330); await tap(195, 360);
  shots.push(await raw());                         // 2 reader
  // 3 — live follower (same context → inherits language)
  try {
    const ws = readFileSync('/tmp/indirimbo_host.txt', 'utf8').trim();
    const fp = await ctx.newPage();
    await fp.goto(`${APP}?join=${encodeURIComponent(ws)}`, { waitUntil: 'load' });
    await settle(fp);
    shots.push((await fp.screenshot()).toString('base64'));
    await fp.close();
  } catch (e) { console.log('share shot skipped:', e.message); shots.push(shots[1]); }
  // 4 — settings: fonts
  await tap(341, 805);
  await p.mouse.move(195, 430); await p.mouse.wheel(0, 720); await p.waitForTimeout(900);
  shots.push(await raw());
  // 5 — library list
  await tap(49, 805);
  await tap(352, 190, 900); // list toggle
  shots.push(await raw());

  await ctx.close();
  return shots;
}

function frameHtml(img, eyebrow, title) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face{font-family:'PF';src:url(data:font/ttf;base64,${playfair}) format('truetype');}
    @font-face{font-family:'MN';src:url(data:font/ttf;base64,${mono}) format('truetype');}
    *{margin:0;padding:0;box-sizing:border-box}html,body{width:100%;height:100%}
    body{display:flex;flex-direction:column;align-items:center;
      background:linear-gradient(165deg,#EFE9DC 0%,#E6DAC2 100%);overflow:hidden}
    .eyebrow{font-family:'MN',monospace;color:#9E4A2C;letter-spacing:.45vw;font-weight:700;font-size:2.3vw;margin-top:7.5vh}
    .title{font-family:'PF',serif;color:#23201A;font-weight:700;font-size:7vw;line-height:1.08;text-align:center;margin-top:1.6vh;padding:0 7vw;white-space:pre-line}
    .device{margin-top:4.2vh;height:70vh;border-radius:4vw;overflow:hidden;box-shadow:0 1.6vw 5vw rgba(40,30,15,.30);border:.35vw solid rgba(0,0,0,.07)}
    .device img{height:100%;display:block}
  </style></head><body>
    <div class="eyebrow">${eyebrow}</div><div class="title">${title}</div>
    <div class="device"><img src="data:image/png;base64,${img}"/></div>
  </body></html>`;
}

for (const lang of ['fr', 'en']) {
  const shots = await captureRaw(lang);
  for (const { store, W: sw, H: sh } of SIZES) {
    const dir = `../store/${store}/${lang}`;
    mkdirSync(dir, { recursive: true });
    const cc = await b.newContext({ viewport: { width: sw, height: sh }, deviceScaleFactor: 1 });
    const pp = await cc.newPage();
    for (let i = 0; i < shots.length; i++) {
      const [eyebrow, title] = CAPTIONS[lang][i];
      await pp.setContent(frameHtml(shots[i], eyebrow, title), { waitUntil: 'load' });
      await pp.waitForTimeout(220);
      await pp.screenshot({ path: `${dir}/${NAMES[i]}.png` });
      console.log('wrote', `${dir}/${NAMES[i]}.png`);
    }
    await cc.close();
  }
}

await b.close();
console.log('DONE');
