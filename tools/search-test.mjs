import { chromium } from 'playwright';
const b = await chromium.launch({ headless: true });
const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForTimeout(7000);
// NO semantics. Tap "Recherche" tab by coordinate.
await page.mouse.click(146, 790);
await page.waitForTimeout(1500);
await page.screenshot({ path: '/tmp/st1_searchtab.png' });
// Tap the search bar to focus
await page.mouse.click(195, 60);
await page.waitForTimeout(1000);
let inputs = await page.evaluate(() => document.querySelectorAll('input,textarea').length);
console.log('inputs after tap:', inputs);
// Try typing
await page.keyboard.type('Jesus', { delay: 120 });
await page.waitForTimeout(1500);
await page.screenshot({ path: '/tmp/st2_typed.png' });
const val = await page.evaluate(() => { const i=document.querySelector('input,textarea'); return i? i.value : null; });
console.log('value after type:', JSON.stringify(val));
await b.close();
