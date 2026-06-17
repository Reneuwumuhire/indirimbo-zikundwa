import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const W = 390, H = 844;
mkdirSync('frames', { recursive: true });
mkdirSync('video', { recursive: true });

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 2,
  recordVideo: { dir: 'video', size: { width: W, height: H } },
});
const page = await ctx.newPage();

let step = 0;
const shot = async (n) => { await page.screenshot({ path: `frames/${String(++step).padStart(2,'0')}-${n}.png` }); console.log('frame', step, n); };
const tap = async (x, y, p = 1200) => { await page.mouse.move(x, y); await page.waitForTimeout(140); await page.mouse.click(x, y); await page.waitForTimeout(p); };
const wheel = async (dy, p = 900) => { await page.mouse.move(195, 430); await page.waitForTimeout(60); await page.mouse.wheel(0, dy); await page.waitForTimeout(p); };
const swipe = async (x1, x2, y, p = 900) => {
  await page.mouse.move(x1, y); await page.mouse.down();
  for (let i = 1; i <= 8; i++) { await page.mouse.move(x1 + (x2 - x1) * i / 8, y); await page.waitForTimeout(16); }
  await page.mouse.up(); await page.waitForTimeout(p);
};

const TAB = { recueils: [49, 805], recherche: [146, 805], favoris: [244, 805], reglages: [341, 805] };
const RH = { back: [28, 34], fav: [266, 34], night: [314, 34], disp: [362, 34] };
const SET = { clair: [85, 131], sepia: [189, 131], sombre: [302, 131] };

await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForTimeout(5000);
await page.setViewportSize({ width: W, height: H + 2 });
await page.waitForTimeout(400);
await page.setViewportSize({ width: W, height: H });
await page.evaluate(() => window.dispatchEvent(new Event('resize')));
await page.waitForTimeout(2200);
await shot('home');

// best-selling card -> reader (emerald header band)
await tap(80, 470, 1400); await shot('reader');
await tap(...RH.fav, 800);
await tap(...RH.night, 1300); await shot('reader-night');
await tap(...RH.night, 1000);
await tap(...RH.back, 1000);   // pop reader -> back to home

// persistent bottom nav -> search
await tap(...TAB.recherche, 1000); await shot('search');
await tap(195, 140, 700);
await page.keyboard.type('yesu', { delay: 95 });
await page.waitForTimeout(1200); await shot('search-results');
await tap(195, 235, 1300); await shot('search-reader');

// favorites
await tap(...TAB.favoris, 1100); await shot('favorites');

// library grid -> tabbed detail
await tap(...TAB.recueils, 900);
await wheel(700); await shot('grid');
await tap(100, 470, 1500); await shot('detail');
await tap(290, 340, 1100); await shot('detail-about');
await tap(100, 340, 1000);
await tap(195, 470, 1300); await shot('detail-song');

// themes
await tap(...TAB.reglages, 1000); await shot('settings');
await tap(...SET.sombre, 1100); await tap(...TAB.recueils, 1000); await shot('home-dark');
await tap(...TAB.reglages, 800); await tap(...SET.sepia, 1000); await tap(...TAB.recueils, 1000); await shot('home-sepia');
await tap(...TAB.reglages, 700); await tap(...SET.clair, 900);

await ctx.close();
await browser.close();
console.log('DONE');
