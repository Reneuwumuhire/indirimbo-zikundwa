# App Privacy answers + App Review notes

## App Privacy ("nutrition label") — App Store Connect → App Privacy

The app collects **no** data. Concretely:
- No account, no login, no analytics, no ads, no third-party SDKs that phone home.
- Settings and favorites are stored **on-device** (SharedPreferences) only.
- "Live share" is **peer-to-peer on the local Wi-Fi** — there is no server and nothing
  is sent to the developer.
- The optional content-update check does a plain GET of a public dataset file from
  GitHub Pages; no user data is transmitted.

**Answer:** "**Data Not Collected**" → select *"I do not collect data from this app."*

(If App Review ever asks: the Local Network usage is solely for the optional live
sing-along; it transmits only the current song id + scroll position between devices on
the same Wi-Fi.)

## Privacy Policy
A policy is already hosted at
`https://reneuwumuhire.github.io/indirimbo-zikundwa/privacy.html`.
Make sure it states: no personal data is collected; settings/favorites stay on the
device; the live-share feature uses the local network only and runs no server. (If it
doesn't yet, update `website/privacy.html` to say this and re-publish.)

## Export Compliance
The app uses only standard HTTPS/WSS (exempt encryption). I've added
`ITSAppUsesNonExemptEncryption = false` to Info.plist, so App Store Connect will **not**
ask the encryption question on every upload. (Answer would otherwise be: uses encryption →
only exempt → no.)

## App Review Notes (paste into "Notes" for the reviewer)
```
Indirimbo Zikundwa is a fully offline hymnal reader. No account or login is required —
open the app and browse immediately.

How to review:
• Browse: tap any collection on the home screen, then any song to read it.
• Search: the Search tab finds songs by number, title, lyrics or author (typo-tolerant).
• Display: Settings lets you change text size, font and theme.

"Partage en direct / Live share" (optional, Local Network permission):
• This is a peer-to-peer sing-along over the same Wi-Fi. There is NO server and NO data
  is sent to us. One device hosts; others on the same network follow the same song and
  scroll position. With a single device it simply shows "no sessions found", which is
  expected. iOS will prompt for Local Network access the first time — tapping Allow is
  only needed to try this optional feature.

The hymn texts are traditional/community hymns compiled for offline reading.
```

## ⚠️ Content rights (Guideline 5.2 — read this)
App Review can reject apps that redistribute copyrighted material without rights.
The hymn texts originate from missionnaire.net. Before/with submission, make sure you
either (a) have permission to distribute these lyrics, or (b) they are public-domain /
community hymns. If you have permission, keep written proof handy in case App Review
asks. This is the **most likely non-technical reason** a hymnal app gets held in review.
