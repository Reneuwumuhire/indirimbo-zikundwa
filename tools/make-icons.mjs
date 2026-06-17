import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const out = new URL('../app/assets/icon/', import.meta.url);
mkdirSync(out, { recursive: true });
const htmlUrl = pathToFileURL(new URL('icon.html', import.meta.url).pathname).href;

const b = await chromium.launch({ headless: true });
const ctx = await b.newContext({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });

async function render(mode, file, omitBackground) {
  const page = await ctx.newPage();
  await page.goto(`${htmlUrl}?mode=${mode}`, { waitUntil: 'load' });
  await page.waitForTimeout(400);
  await page.locator('#stage').screenshot({
    path: new URL(file, out).pathname,
    omitBackground,
  });
  await page.close();
  console.log('rendered', file);
}

await render('full', 'icon.png', false);     // master, navy bg (iOS/web)
await render('fg', 'icon_foreground.png', true); // adaptive foreground, transparent
await b.close();
console.log('done');
