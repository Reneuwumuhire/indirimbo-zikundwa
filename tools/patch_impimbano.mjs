// One-off: fetch the Impimbano pages, read the artist line (<div class="pr">),
// and set it as the `author` on the matching songs in the bundled dataset.
// (The scraper now captures div.pr too; this patches the existing JSON without
// a full re-scrape.)

import { readFileSync, writeFileSync } from 'node:fs';

const BASE = 'https://indirimbo-zikundwa.bi/Indirimbo';
const pad = (n) => String(n).padStart(3, '0');
const clean = (s) =>
  (s || '').replace(/ /g, ' ').replace(/\s+/g, ' ').trim();

const path = new URL('../app/assets/data/hymns.json', import.meta.url);
const data = JSON.parse(readFileSync(path, 'utf8'));

async function prFor(n) {
  try {
    const r = await fetch(`${BASE}/Impimbano-${pad(n)}.html`);
    if (!r.ok) return null;
    const html = await r.text();
    const m = html.match(/<div class="pr">([\s\S]*?)<\/div>/);
    if (!m) return null;
    // Strip the inline <span> tags WITHOUT inserting spaces — the source splits
    // names mid-word across spans (e.g. "Ren<span>é</span>"); real spaces are
    // text nodes and are preserved.
    const text = clean(m[1].replace(/<[^>]+>/g, ''));
    return text || null;
  } catch {
    return null;
  }
}

let updated = 0;
const credits = {};
for (let n = 1; n <= 98; n++) {
  const pr = await prFor(n);
  if (pr) credits[n] = pr;
}
console.log('pages with an artist:', Object.keys(credits).length);

for (const s of data.songs) {
  if (s.series !== 'Impimbano') continue;
  const pr = credits[s.file];
  if (pr) {
    s.author = pr;
    updated++;
  }
}

writeFileSync(path, JSON.stringify(data));
console.log('songs updated with author:', updated);
