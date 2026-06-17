// Scrapes all hymn collections (published by missionnaire.net) from the public
// indirimbo-zikundwa.bi SIL Reading App Builder deployment into a single bundled
// JSON dataset for the Flutter app.
//
// Page model per /Indirimbo/{Series}-{NNN}.html:
//   <div class="pc">{COLLECTION} №</div>     -> collection header (ignored)
//   <div class="pc">1A</div>                 -> number+variant label
//   <div class="s"><div id="sN">TITLE</div>  -> song title
//   <ol start="k"><li>verse text</li></ol>   -> a verse stanza
//   <div class="pc">refrain text</div>       -> chorus/refrain stanza
//   <div class="pc">************</div>        -> song boundary (one page may hold A/B songs)

import { load } from 'cheerio';
import { writeFileSync, mkdirSync } from 'node:fs';

const BASE = 'https://indirimbo-zikundwa.bi/Indirimbo';
const OUT_DIR = new URL('../app/assets/data/', import.meta.url);

// All 17 collections, in the website dropdown order.
// { code, from, to, name }  — `from` defaults to 1; Umuco-2 files start at 401.
const SERIES = [
  { code: 'Umuco', to: 315, name: 'Umuco' },
  { code: 'Umuco-1', to: 400, name: 'Umuco 1' },
  { code: 'Umuco-2', from: 401, to: 827, name: 'Umuco 2' },
  { code: 'Ikirundi', to: 354, name: 'Ikirundi' },
  { code: 'Izigisenyi', to: 241, name: "Iz'i Gisenyi" },
  { code: 'Gushimisha', to: 437, name: 'Gushimisha' },
  { code: 'Agakiza', to: 110, name: 'Agakiza' },
  { code: 'Wokovu', to: 335, name: 'Wokovu' },
  { code: 'N-Mungu', to: 327, name: 'Nyimbo za Mungu' },
  { code: 'T-Rohoni', to: 161, name: 'Tenzi za Rohoni' },
  { code: 'A-Foi', to: 655, name: 'Les Ailes de la Foi' },
  { code: 'C-Victoire', to: 311, name: 'Chants de Victoire' },
  { code: 'C-Cantiques', to: 640, name: 'Coll. des Cantiques' },
  { code: 'C-Seulement', to: 226, name: 'Crois Seulement' },
  { code: 'Impimbano', to: 98, name: 'Impimbano' },
  { code: 'Chorus', to: 52, name: 'Chorus' },
  { code: 'Izindi', to: 283, name: 'Izindi' },
];

const CONCURRENCY = 16;
const pad = (n) => String(n).padStart(3, '0');
const clean = (s) => (s || '').replace(/ /g, ' ').replace(/\s+/g, ' ').trim();

async function fetchText(url, tries = 3) {
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url);
      if (r.status === 404) return null;
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return await r.text();
    } catch (e) {
      if (i === tries - 1) throw e;
      await new Promise((res) => setTimeout(res, 400 * (i + 1)));
    }
  }
}

// Parse one page's HTML into an array of song objects (1 or more = A/B variants).
function parsePage(html, series, fileNum) {
  const $ = load(html);
  const content = $('#content').first();
  const songs = [];
  let cur = null;
  let pendingLabel = null;
  let bodyEnded = false; // true after a "****" separator, until the next song starts

  const startSong = () => {
    cur = { label: pendingLabel, title: '', stanzas: [], author: '' };
    pendingLabel = null;
    bodyEnded = false;
  };
  const pushCur = () => {
    if (cur && (cur.title || cur.stanzas.length)) songs.push(cur);
    cur = null;
  };

  content.find('div.s, div.pc, div.pr, div.m, div.p, ol').each((_, el) => {
    const tag = el.tagName.toLowerCase();
    const $el = $(el);

    // Artist / credit line (e.g. Impimbano "Fr Siméon") -> author.
    if (tag === 'div' && $el.hasClass('pr')) {
      const credit = clean($el.text());
      if (cur && credit) {
        cur.author = cur.author ? `${cur.author} · ${credit}` : credit;
      }
      return;
    }

    // Title — always begins a song
    if (tag === 'div' && $el.hasClass('s')) {
      if (cur && cur.title) pushCur();
      if (!cur) startSong();
      cur.title = clean($el.text());
      cur.label = cur.label ?? pendingLabel;
      pendingLabel = null;
      bodyEnded = false;
      return;
    }

    if (tag === 'ol') {
      if (bodyEnded) return; // stray verses after the end marker — ignore
      if (!cur) startSong();
      $el.find('li').each((__, li) => {
        const t = clean($(li).text());
        if (t) cur.stanzas.push({ type: 'verse', text: t });
      });
      return;
    }

    // text-bearing div: pc (centered/refrain), m or p (paragraph)
    const isPc = tag === 'div' && $el.hasClass('pc');
    const raw = clean($el.text());
    if (!raw) return;
    if (/№/.test(raw)) return; // collection header
    if (/^\*+$/.test(raw.replace(/\s/g, ''))) { bodyEnded = true; return; } // end marker
    if (isPc && /^\d+\s*[A-Za-z]?$/.test(raw)) {
      // a number label announces the next song (e.g. A/B variants on one page)
      if (cur) pushCur();
      pendingLabel = raw.replace(/\s/g, '');
      bodyEnded = false;
      return;
    }

    if (bodyEnded) {
      // trailing credit after the song body (author / composer) — keep as metadata
      if (cur) cur.author = cur.author ? `${cur.author} · ${raw}` : raw;
      return;
    }
    if (!cur) startSong();
    // pc -> chorus/refrain; m/p -> verse paragraph
    cur.stanzas.push({ type: isPc ? 'chorus' : 'verse', text: raw });
  });
  pushCur();

  // normalise into final records
  return songs.map((s, idx) => {
    const m = (s.label || '').match(/^(\d+)([A-Za-z])?$/);
    const number = m ? parseInt(m[1], 10) : fileNum;
    const variant = m && m[2] ? m[2].toUpperCase() : null;
    const label = s.label || String(fileNum);
    return {
      id: `${series}-${pad(fileNum)}${variant ? '-' + variant : idx ? '-' + idx : ''}`,
      series,
      file: fileNum,
      number,
      variant,
      label,
      title: s.title || `${label}`,
      author: s.author || null,
      stanzas: s.stanzas,
      lyrics: s.stanzas.map((x) => x.text).join(' \n '),
    };
  });
}

async function seriesDisplayName(code, count) {
  for (let n = 1; n <= Math.min(count, 5); n++) {
    const html = await fetchText(`${BASE}/${code}-${pad(n)}.html`);
    if (!html) continue;
    const $ = load(html);
    const title = clean($('title').first().text());
    const name = title.replace(/\s*\d+\s*$/, '').trim();
    if (name) return name;
  }
  return code;
}

async function mapLimit(items, limit, fn) {
  const out = [];
  let i = 0;
  const workers = Array.from({ length: limit }, async () => {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  });
  await Promise.all(workers);
  return out;
}

async function run() {
  mkdirSync(OUT_DIR, { recursive: true });
  const collections = [];
  const allSongs = [];

  for (const { code, from = 1, to, name: fixedName } of SERIES) {
    const count = to - from + 1;
    const name = fixedName || (await seriesDisplayName(code, to));
    process.stdout.write(`\n[${code}] "${name}" (${count} files) `);
    const nums = Array.from({ length: count }, (_, i) => i + from);
    let done = 0;
    const pages = await mapLimit(nums, CONCURRENCY, async (n) => {
      const html = await fetchText(`${BASE}/${code}-${pad(n)}.html`);
      done++;
      if (done % 50 === 0) process.stdout.write('.');
      if (!html) return [];
      try {
        return parsePage(html, code, n);
      } catch (e) {
        console.error(`\n  parse error ${code}-${pad(n)}: ${e.message}`);
        return [];
      }
    });
    const songs = pages.flat();
    songs.forEach((s) => allSongs.push(s));
    collections.push({ id: code, name, songCount: songs.length });
    process.stdout.write(` -> ${songs.length} songs`);
  }

  const dataset = {
    generatedFrom: 'https://indirimbo-zikundwa.bi',
    collections,
    songs: allSongs,
  };
  const outFile = new URL('hymns.json', OUT_DIR);
  writeFileSync(outFile, JSON.stringify(dataset));
  const variants = allSongs.filter((s) => s.variant).length;
  console.log(`\n\nDONE: ${allSongs.length} songs in ${collections.length} collections (${variants} A/B variants).`);
  console.log(`Wrote ${outFile.pathname}`);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
