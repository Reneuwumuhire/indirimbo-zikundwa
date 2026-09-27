import { readFile, mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.resolve(process.argv[2] || path.join(root, 'website'));
const site = 'https://indirimbo-zikundwa.github.io';
const data = JSON.parse(await readFile(path.join(root, 'app/assets/data/hymns.json'), 'utf8'));
const collections = new Map(data.collections.map((collection) => [collection.id, collection]));
const songsDir = path.join(output, 'songs');

const escapeHtml = (value = '') => String(value)
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#39;');

const properNouns = new Set([
  'yesu', 'yezu', 'imana', 'mungu', 'dieu', 'jesus', 'jésus', 'christ',
  'kristo', 'yehova', 'yahweh', 'roho', 'mwami', 'mana', 'alleluia', 'alleluya',
  'haleluya', 'jehovah',
]);

const capitalize = (word) => word.replace(/\p{L}/u, (letter) => letter.toLocaleUpperCase());
const displayTitle = (raw) => {
  const title = raw.trim();
  if (!title || title !== title.toLocaleUpperCase()) return raw;
  const words = title.toLocaleLowerCase().split(' ');
  for (let i = 0; i < words.length; i++) {
    const key = words[i].replaceAll(/[^a-zà-ÿ]/g, '');
    if (properNouns.has(key)) words[i] = capitalize(words[i]);
  }
  const first = words.findIndex((word) => word.trim());
  if (first >= 0) words[first] = capitalize(words[first]);
  return words.join(' ');
};

const filename = (song) => `${encodeURIComponent(song.id)}.html`;
const songUrl = (song) => `${site}/songs/${filename(song)}`;
const excerpt = (song) => song.lyrics.replaceAll(/\s+/g, ' ').trim().slice(0, 155);
const json = (value) => JSON.stringify(value).replaceAll('<', '\\u003c');

const shell = ({ title, description, canonical, body, structuredData = null }) => `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="theme-color" content="#f3ead9">
  <link rel="canonical" href="${canonical}">
  <link rel="icon" href="../assets/favicon.png">
  <link rel="stylesheet" href="../song.css">
  <meta property="og:type" content="article">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${canonical}">
  ${structuredData ? `<script type="application/ld+json">${json(structuredData)}</script>` : ''}
</head>
<body>
${body}
</body>
</html>
`;

await rm(songsDir, { recursive: true, force: true });
await mkdir(songsDir, { recursive: true });

const byCollection = new Map(data.collections.map((collection) => [collection.id, []]));
for (const song of data.songs) {
  if (!collections.has(song.series)) throw new Error(`Unknown collection: ${song.series}`);
  byCollection.get(song.series).push(song);
}

for (const songs of byCollection.values()) {
  songs.sort((a, b) => a.number - b.number || (a.variant || '').localeCompare(b.variant || ''));
  for (let i = 0; i < songs.length; i++) {
    const song = songs[i];
    const collection = collections.get(song.series);
    const title = displayTitle(song.title);
    const previous = songs[i - 1];
    const next = songs[i + 1];
    let verse = 0;
    const stanzas = song.stanzas.map((stanza) => {
      const chorus = stanza.type === 'chorus';
      const label = chorus ? 'Refrain' : `Couplet ${++verse}`;
      return `<section class="stanza${chorus ? ' chorus' : ''}"><h2>${label}</h2><p>${escapeHtml(stanza.text)}</p></section>`;
    }).join('\n');
    const description = `${collection.name} #${song.label}. ${excerpt(song)}`;
    const canonical = songUrl(song);
    const body = `<header class="masthead">
  <a class="brand" href="../">Indirimbo Zikundwa</a>
  <a class="open-app" href="../app/?song=${encodeURIComponent(song.id)}">Open in the app</a>
</header>
<main class="hymn">
  <p class="number">#${escapeHtml(song.label)}</p>
  <h1>${escapeHtml(title)}</h1>
  <p class="collection">${escapeHtml(collection.name)}${song.author ? `<span class="author">· ${escapeHtml(song.author)}</span>` : ''}</p>
  <div class="rule"></div>
  ${stanzas}
</main>
<nav class="pager" aria-label="Hymns in ${escapeHtml(collection.name)}">
  <span>${previous ? `<a href="${filename(previous)}" rel="prev">‹ ${escapeHtml(previous.label)}. ${escapeHtml(displayTitle(previous.title))}</a>` : ''}</span>
  <a class="all-songs" href="./">All songs</a>
  <span class="next">${next ? `<a href="${filename(next)}" rel="next">${escapeHtml(next.label)}. ${escapeHtml(displayTitle(next.title))} ›</a>` : ''}</span>
</nav>`;
    const structuredData = {
      '@context': 'https://schema.org',
      '@type': 'MusicComposition',
      name: title,
      url: canonical,
      isPartOf: { '@type': 'Book', name: collection.name },
      lyrics: { '@type': 'CreativeWork', text: song.lyrics },
      ...(song.author ? { composer: { '@type': 'Person', name: song.author } } : {}),
    };
    await writeFile(path.join(songsDir, filename(song)), shell({
      title: `${title} — ${collection.name} #${song.label}`,
      description,
      canonical,
      body,
      structuredData,
    }));
  }
}

const directory = [...byCollection].map(([id, songs]) => {
  const collection = collections.get(id);
  const links = songs.map((song) => `<li><a href="${filename(song)}"><span>${escapeHtml(song.label)}</span> ${escapeHtml(displayTitle(song.title))}</a></li>`).join('\n');
  return `<section><h2>${escapeHtml(collection.name)}</h2><ul class="song-links">${links}</ul></section>`;
}).join('\n');

await writeFile(path.join(songsDir, 'index.html'), shell({
  title: 'All hymns — Indirimbo Zikundwa',
  description: `Browse all ${data.songs.length.toLocaleString('en')} hymns in the Indirimbo Zikundwa library.`,
  canonical: `${site}/songs/`,
  body: `<header class="masthead"><a class="brand" href="../">Indirimbo Zikundwa</a><a class="open-app" href="../app/">Open the app</a></header><main class="directory"><h1>All hymns</h1><p>${data.songs.length.toLocaleString('en')} songs across ${data.collections.length} collections.</p><div class="collection-list">${directory}</div></main>`,
}));

const sitemapPath = path.join(output, 'sitemap.xml');
const sitemap = await readFile(sitemapPath, 'utf8');
const urls = [`${site}/songs/`, ...data.songs.map(songUrl)]
  .map((url) => `  <url><loc>${url}</loc><changefreq>yearly</changefreq><priority>0.7</priority></url>`)
  .join('\n');
await writeFile(sitemapPath, sitemap.replace('</urlset>', `${urls}\n</urlset>`));

if (new Set(data.songs.map((song) => song.id)).size !== data.songs.length) {
  throw new Error('Song IDs must be unique');
}
console.log(`Generated ${data.songs.length} indexable hymn pages in ${songsDir}`);
