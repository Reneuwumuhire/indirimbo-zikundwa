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
  sitemap.xml     base sitemap (hymn URLs are added at deploy time)
  song.css        indexable hymn-page styles
  assets/         icon, favicon, and app screenshots
```

`tools/build-song-pages.mjs` generates `/songs/`, one static HTML page per hymn,
and adds those URLs to the deployed sitemap. Generated pages stay out of this
source tree and are created during deployment.

## App links

The download cards link directly to Google Play, the App Store, and `/app/` for
the browser version.

## Deploy

Run `tools/publish-org-site.sh` to build the Flutter app, combine it with the
landing site, and publish both at `https://indirimbo-zikundwa.github.io/`.

Pushes to `main` also deploy a mirror at the source repository's GitHub Pages
URL through `.github/workflows/deploy-pages.yml`.

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
