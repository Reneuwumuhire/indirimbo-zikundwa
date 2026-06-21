# Indirimbo Zikundwa — landing site

A static, single-page landing site for the **Indirimbo Zikundwa** hymnal app,
published with **GitHub Pages**.

**Live:** https://reneuwumuhire.github.io/indirimbo-zikundwa/

## Files

```
website/
  index.html      the page (semantic, SEO + Open Graph + JSON-LD)
  styles.css      warm parchment "Cantica" hymnal theme
  app.js          auto-wires the download buttons to GitHub Release assets
  robots.txt      crawl + sitemap
  sitemap.xml     single-URL sitemap
  assets/         icon, favicon, and app screenshots
```

## Download buttons

The three download cards (Android · iOS · Web) start as **placeholders** that link
to the [Releases page](https://github.com/Reneuwumuhire/indirimbo-zikundwa/releases)
and show a *"Build coming soon"* badge.

`app.js` reads the public Releases API on load and, as soon as you upload the real
artifacts, automatically rewires each card to the direct asset URL and flips its
badge to **Ready**. The matchers it looks for (case-insensitive):

| Card    | Filename pattern matched         | Example artifact |
| ------- | -------------------------------- | ---------------- |
| Android | `*.apk`                          | `indirimbo-zikundwa.apk` |
| iOS     | `*.ipa` / `*.tipa`               | `indirimbo-zikundwa.ipa` |
| Web     | `*web*.zip` (else any archive)   | `indirimbo-web.zip` |

So once you build on another machine, just attach those files to a GitHub Release
— **no website change needed**.

## Deploy

Pushing any change under `website/` to `main` triggers
`.github/workflows/deploy-pages.yml`, which uploads `website/` as the Pages
artifact and deploys it.

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
