# Google Play submission — step by step

You'll need a **Google Play Developer account** (one-time **$25**, sign up at
https://play.google.com/console). Once you have it:

## 1. Signing — already done ✅ (but back this up!)
The app is signed with a real **upload key** we generated:
- Keystore: `app/android/upload-keystore.jks`
- Credentials: `app/android/key.properties`  *(both are gitignored)*

⚠️ **Back up `upload-keystore.jks` and its password somewhere safe** (password
manager + offline copy). With **Play App Signing** (on by default) Google holds
the real app-signing key and you upload with this key; if you ever lose it,
Google can reset the upload key — but keep it safe anyway.

## 2. Create the app in Play Console
Play Console → **Create app**:
- App name: **Indirimbo Zikundwa**
- Default language: **English (United States)**
- App or game: **App**
- Free or paid: **Free**
- Accept the declarations.

## 3. Set up the store listing  (Grow → Store presence → Main store listing)
Copy from `metadata.md`:
- App name, short description, full description.
- **App icon:** upload `assets/play-icon-512.png`.
- **Feature graphic:** upload `assets/feature-graphic-1024x500.png`.
- **Phone screenshots:** upload the 4 PNGs from `screenshots/phone/` (2–8 required).
- Category: **Books & Reference**; add the contact email + privacy policy URL.

## 4. Complete the required policy sections (Policy → App content)
- **Privacy policy:** `https://indirimbo-zikundwa.github.io/privacy.html`
- **Data safety:** see `data-safety.md` → answer **"No data collected / shared."**
- **Ads:** No ads.
- **Content rating:** fill the IARC questionnaire → Everyone / PEGI 3.
- **Target audience:** 13+ (not designed for children).
- **Government apps / News / COVID:** No.

## 5. Upload the build
- **App bundle:** `app/build/app/outputs/bundle/release/app-release.aab`
  (a copy is at `Indirimbo-Zikundwa-v1.0.0-2.aab`).
- Start with **Testing → Internal testing** (fastest, no review wait): create a
  release, upload the .aab, add your email as a tester, and install via the opt-in
  link to sanity-check. Then promote to **Production**.
- Or go straight to **Production → Create new release** → upload the .aab.
- Play App Signing: when prompted, **let Google manage the app signing key**
  (recommended). It will use our upload key to verify uploads.

## 6. Roll out
Add release notes (from `metadata.md`), review the summary, and **Send for review**.
First review for a new account can take a few days; updates are usually faster.

## Rebuilding for future updates
1. Bump `version:` in `app/pubspec.yaml` (e.g. `1.0.1+3` — versionCode must increase).
2. `cd app && flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
3. Upload the new `.aab` and roll out.

## Notes
- The 58 MB .aab is the *bundle*; Google generates per-device APKs, so users
  download ~20 MB.
- `minSdk`/`targetSdk` come from Flutter (compileSdk 36) — meets Play's current
  target-API requirement.
- Android package id is `bi.indirimbozikunzwe` — the same as the iOS bundle id
  and matching the Play Console app record.
