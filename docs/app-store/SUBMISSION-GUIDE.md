# App Store submission — step by step

Everything you need is in this folder:
- `metadata.md` — all text fields (name, subtitle, description, keywords, URLs…).
- `privacy-and-review.md` — App Privacy answers, App Review notes, export compliance, content-rights note.
- `screenshots/6.9-inch/*.png` — 4 screenshots at 1320×2868 (the required 6.9" size).
- App icon (1024, opaque) ships **inside the build** (generated from `assets/icon/icon.png`); no separate upload needed.

You already have a paid Apple Developer account + App Store Connect (the "Users and Access" page), so you're past the hardest prerequisite.

---

## 0. One-time prerequisites
- A **Mac with Xcode** (you have Xcode 26) signed in with your Apple ID:
  Xcode → Settings → Accounts → add your Apple ID (the one on the paid team).
- Confirm the bundle id **`bi.indirimbozikunzwe`** is what you want (it's set in the project). The App Store name can differ from the bundle id.

## 1. Create the app record in App Store Connect
App Store Connect → **Apps → ➕ → New App**:
- Platform: **iOS**
- Name: **Indirimbo Zikundwa** (must be unique on the App Store; if taken, add a word, e.g. "Indirimbo Zikundwa – Hymnal")
- Primary language: **English (U.S.)**
- Bundle ID: select **bi.indirimbozikunzwe** (register it first in *Certificates, IDs & Profiles → Identifiers* if it's not in the dropdown)
- SKU: anything unique, e.g. `indirimbo-zikundwa`
- Full access.

## 2. Fill the listing (from `metadata.md`)
In the app's **(version) page** and **App Information**:
- App name, subtitle, promotional text, description, keywords, support URL, marketing URL → copy from `metadata.md`.
- **Category:** Books (primary). **Age rating:** 4+ (answer "None" to everything).
- **Privacy Policy URL:** `https://indirimbo-zikundwa.github.io/privacy.html`.
- Upload the 4 **screenshots** to the **6.9" iPhone** slot (drag the PNGs from `screenshots/6.9-inch/`). One size set is enough — App Store reuses 6.9" for smaller iPhones.

## 3. App Privacy
App Store Connect → **App Privacy** → "**Data Not Collected**" (see `privacy-and-review.md`). Publish.

## 4. Build & upload the app
Export compliance is pre-answered in Info.plist, so uploads won't prompt for it.

**Option A — local (Xcode):**
```
cd app
flutter build ipa --release
```
Then open `app/build/ios/archive/Runner.xcarchive` in **Xcode → Window → Organizer → Distribute App → App Store Connect → Upload**. Xcode handles distribution signing automatically (Automatic signing + your team R9SGKU48YJ).

> If you hit *"App ID … cannot be registered / no profiles"*: open `app/ios/Runner.xcworkspace` in Xcode → select the **Runner** target → **Signing & Capabilities** → ensure **Automatically manage signing** is on and your **Team** is selected → Xcode re-creates the App ID + profile. (This is the same hiccup we saw locally.)

**Option B — Xcode Cloud (you have it enabled):** create a workflow that archives on push and delivers to TestFlight/App Store Connect. This avoids local signing/build issues entirely.

After upload, the build appears under **TestFlight** (processing takes 5–30 min). Optionally test it via TestFlight on your iPhone.

## 5. Attach the build & submit
On the version page → **Build → +** → select the uploaded build. Then **Add for Review → Submit**.
- Paste the **App Review notes** from `privacy-and-review.md` (explains the offline app + the optional Local Network live-share, which reviewers test).
- Pricing: **Free**.

## 6. Likely review pitfalls (read before submitting)
1. **Content rights (Guideline 5.2):** make sure you have permission to distribute the hymn lyrics, or that they're public-domain. This is the #1 non-technical reason a hymnal app gets held. Keep proof handy.
2. **Local Network prompt (Guideline 5.1.1):** the `NSLocalNetworkUsageDescription` string is already set and the review note explains the feature is optional — good.
3. **Minimum functionality (4.2):** the app is feature-rich (search, reader, themes, sharing) — fine.

## Version bumping for future updates
Edit `version:` in `app/pubspec.yaml` (e.g. `1.0.1+2`), rebuild, upload, add "What's New", submit.
