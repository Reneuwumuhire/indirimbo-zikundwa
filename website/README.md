# Indirimbo Zikundwa — landing site

A landing site and the Flutter web version of the **Indirimbo Zikundwa** hymnal
app, published together with **GitHub Pages**.

**Live:** https://indirimbo-zikundwa.github.io/

## Files

```
website/
  index.html      the page (semantic, SEO + Open Graph + JSON-LD)
  styles.css      warm parchment "Cantica" hymnal theme
  app.js          tiny scroll-reveal enhancement
  robots.txt      crawl + sitemap
  sitemap.xml     single-URL sitemap
  assets/         icon, favicon, and app screenshots
```

## App links

The download cards link directly to Google Play, the App Store, and `/app/` for
the browser version.

## Deploy

Pushing a change under `website/` or `app/` to `main` triggers
`.github/workflows/deploy-pages.yml`. It builds the Flutter app with `/app/` as
its base path, combines it with the landing site, and deploys both.

One-time setup in the repo: **Settings → Pages → Build and deployment → Source:
GitHub Actions**.

## Updating screenshots

The screenshots in `assets/` are downscaled copies of the marketed store shots in
[`/store/appstore/en`](../store/appstore/en). To refresh them:

```bash
for n in 01-library 02-reader 03-share 04-fonts 05-languages; do
  sips -Z 900 store/appstore/en/$n.png --out website/assets/shot-${n#*-}.png
done
```
