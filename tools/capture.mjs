import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
const W = 390, H = 844;
mkdirSync('caps', { recursive: true });
const b = await chromium.launch({ headless: true });
const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
let n = 0;
const shot = async (name) => { await page.screenshot({ path: `caps/${String(++n).padStart(2,'0')}-${name}.png` }); console.log('shot', name); };
const tap = async (x, y, p = 1300) => { await page.mouse.move(x, y); await page.waitForTimeout(120); await page.mouse.click(x, y); await page.waitForTimeout(p); };
const wheel = async (dy, p = 900) => { await page.mouse.wheel(0, dy); await page.waitForTimeout(p); };

await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForTimeout(5000);
await page.setViewportSize({ width: W, height: H + 2 });
await page.waitForTimeout(400);
await page.setViewportSize({ width: W, height: H });
await page.evaluate(() => window.dispatchEvent(new Event('resize')));
await page.waitForTimeout(2200);
await shot('home');

// Best-selling song card -> reader
await tap(80, 470, 1400); await shot('reader');
await tap(28, 34, 1100); // header-band back

// Scroll to grid, open a cover -> collection detail
await wheel(700); await shot('grid');
await tap(100, 470, 1500); await shot('collection');   // grid cover -> detail
await tap(290, 300, 1200); await shot('about');         // À propos tab
await tap(100, 300, 1100); await shot('chants');        // back to Chants tab
await tap(195, 470, 1400); await shot('song');          // open a song

await b.close();
console.log('done');
