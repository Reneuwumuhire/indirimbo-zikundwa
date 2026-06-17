import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
const W = 390, H = 844;
mkdirSync('dbg', { recursive: true });
const b = await chromium.launch({ headless: true });
const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
page.on('pageerror', (e) => console.log('PAGEERROR:', e.message.slice(0, 300)));
page.on('console', (m) => { if (m.type() === 'error') console.log('CONSOLE-ERR:', m.text().slice(0, 300)); });
let n = 0;
const shot = async (name) => { await page.screenshot({ path: `dbg/${String(++n).padStart(2,'0')}-${name}.png` }); console.log('shot', name); };
const tap = async (x, y, p = 1200) => { await page.mouse.move(x, y); await page.waitForTimeout(120); await page.mouse.click(x, y); await page.waitForTimeout(p); };

await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForTimeout(5000);
await page.setViewportSize({ width: W, height: H + 2 });
await page.waitForTimeout(400);
await page.setViewportSize({ width: W, height: H });
await page.evaluate(() => window.dispatchEvent(new Event('resize')));
await page.waitForTimeout(2200);
await shot('home');
await page.mouse.wheel(0, 700); await page.waitForTimeout(900); await shot('scrolled');
// tap where a grid cover should be (top-left grid item)
await tap(110, 300, 1600); await shot('after-tap');
await b.close();
console.log('done');
