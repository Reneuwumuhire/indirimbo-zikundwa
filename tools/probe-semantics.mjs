import { chromium } from 'playwright';
const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForTimeout(6000);

// Enable Flutter's accessibility/semantics tree so the DOM exposes labels.
const placeholder = await page.$('flt-semantics-placeholder, [aria-label="Enable accessibility"]');
console.log('placeholder found:', !!placeholder);
if (placeholder) {
  await placeholder.evaluate((el) => el.click());
  await page.waitForTimeout(2500);
}
const labels = await page.evaluate(() => {
  const out = [];
  document.querySelectorAll('flt-semantics[aria-label], [role="button"][aria-label], a[aria-label]').forEach((n) => {
    const l = n.getAttribute('aria-label');
    if (l) out.push((n.getAttribute('role') || n.tagName.toLowerCase()) + ': ' + l);
  });
  return out.slice(0, 40);
});
console.log('LABEL COUNT-ish:', labels.length);
console.log(labels.join('\n'));
await browser.close();
