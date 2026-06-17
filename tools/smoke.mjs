import { chromium } from 'playwright';

const URL = 'http://localhost:8099/';
const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
});
const page = await ctx.newPage();
page.on('console', (m) => console.log('PAGE:', m.type(), m.text().slice(0, 200)));
page.on('pageerror', (e) => console.log('PAGEERROR:', e.message));
await page.goto(URL, { waitUntil: 'load' });
// Wait for the flutter glasspane / rendered content
await page.waitForTimeout(8000);
await page.screenshot({ path: 'smoke.png' });
// Try to read any visible text
const text = await page.evaluate(() => document.body.innerText.slice(0, 400));
console.log('VISIBLE TEXT:', JSON.stringify(text));
await browser.close();
console.log('smoke done');
