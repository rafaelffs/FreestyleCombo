# FreestyleCombo — App Store submission kit

Mirrors the process used for the Flaggio app (`docs/app-store-listing.md` in that repo) — closed TestFlight beta first, full listing when ready to go public. FreestyleCombo ships via Xcode (`flutter build ipa`), not Expo/EAS, but the Apple-side steps and metadata shape are the same.

---

## 1. Closed beta (TestFlight)

1. Set `DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj` once you have a paid Apple Developer Program Team ID (see the checklist below — the certificate currently on this machine, "Apple Development: rafael.ffs@hotmail.com (R74Z8T6W8L)", needs confirming as a paid team, not just a free personal-team signing identity).
2. `cd mobile && flutter build ipa --release` → produces `build/ios/ipa/freestyle_combo.ipa`.
3. Upload via Xcode Organizer or Transporter (drag the `.ipa` in). First upload creates the app record if you haven't made one yet in App Store Connect — otherwise attaches to the existing one.
4. In App Store Connect → **TestFlight** tab, the build appears after processing (~10–30 min).
5. Fill **Beta App Information** once: beta description, feedback email, privacy policy URL (`https://www.fscombo.com/privacy`), export compliance (FreestyleCombo only uses standard HTTPS/TLS — answer "uses standard encryption only", no `ITSAppUsesNonExemptEncryption` exemption needed).
6. **Internal Testing** (up to 100 ASC team members, no review, instant) is enough for solo/close-friends testing. **External Testing** (up to 10,000 testers by email or link, ~1 day Beta App Review on first build) is the real "closed beta" — nothing is publicly listed either way.
7. Builds expire after 90 days.

**Going live later**: same App Store Connect app record, add §2–§4 below, pick "Manually release", submit for full App Review.

---

## 2. App Store listing (copy-paste)

| Field | Value |
|---|---|
| **Name** (30 ch) | `FreestyleCombo` |
| **Subtitle** (30 ch) | `Freestyle football combos` |
| **Primary category** | Sports |
| **Secondary category** | Lifestyle |
| **Age rating** | 4+ (no objectionable content; questionnaire: all "No") |
| **Price** | Free |
| **Bundle ID** | `com.rafaelffs.freestyleCombo` |

**Promotional text** (170 ch, editable without review):

> Generate freestyle football combos, build your own trick sequences, rate what other players create, and track the combos you've mastered.

**Description:**

> FreestyleCombo helps you build, generate and share freestyle football trick combos.
>
> GENERATE OR BUILD
> • Auto-generate a combo from your own preferences — max difficulty, combo length, strong/weak foot split, no-touch frequency
> • Or build one manually, trick by trick, from the full trick library
> • Save named presets so you don't have to re-tune settings every time
>
> A LIVING TRICK LIBRARY
> • Browse every trick with its difficulty, revolutions and crossover/knee flags
> • Don't see a trick you know? Submit it — approved submissions join the library for everyone
>
> SHARE & RATE
> • Publish combos you're proud of for other users to see
> • Rate combos other players share
> • Mark combos as done as you complete them, and favourite the ones you want to come back to
>
> YOUR PROGRESS
> • Track your combo count, completions and average rating from your profile
> • Reusable combos can be chained into other combos as building blocks
>
> Works with your FreestyleCombo web account — sign in with the same username or email.

**Keywords** (100 ch, no spaces after commas):

```
freestyle,football,soccer,tricks,combo,juggling,skills,training,football freestyle,ball control
```

**What's New** (first release — never say "beta"/"test" in App Store metadata, guideline 2.3.10):

> First release — generate or build freestyle football combos, rate combos from other players, and track the tricks you've mastered.

**URLs:** Support: `https://www.fscombo.com` · Marketing: `https://www.fscombo.com` · Privacy policy: `https://www.fscombo.com/privacy` · Terms: `https://www.fscombo.com/terms` (all live).

---

## 3. Screenshots — what Apple requires and what to shoot

Required: **6.9" set** (1320×2868, iPhone 16 Pro Max class — the QA simulator already used for this project matches this class exactly). Optional: 6.1" set (1206×2622). Up to 10 per size; the first 3 do the selling.

Shot list, in order:

1. **Combos list** — public tab with a few combos showing names, difficulty, owner
2. **Generate flow** — the preview screen with a freshly generated combo and its trick sequence
3. **Build mode** — the manual trick picker with the "My Combo" slot list
4. **Combo detail** — the gradient hero, numbered trick sequence, rating/favourite/done icons
5. **Tricks library** — the trick list with difficulty chips and the type filter (tricks/combos)
6. **Profile** — the gradient header with combo/done/rating stats

Capture via the booted simulator: `xcrun simctl io booted screenshot <path>.png`, or Cmd+S in Simulator.app. Real data beats fixtures — use the app signed in as a normal (non-review) account with a few saved combos.

**App icon:** already in place — `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`. App Store Connect pulls it from the build automatically.

---

## 4. App Privacy questionnaire (App Store Connect → App Privacy)

Declare **Data linked to you** (no tracking, no third-party ads):

| ASC category | What it is in FreestyleCombo | Purpose |
|---|---|---|
| Contact Info → Email address | account email | App functionality |
| User Content → Other user content | combos, trick sequences, preferences, ratings, trick submissions | App functionality |
| Identifiers → User ID | account id / username | App functionality |
| Sensitive info | **No** | — |
| Tracking (ATT) | **No** — nothing used for cross-app tracking, no ads | — |

Anthropic's Claude API is called server-side to write an optional AI description for generated combos — only trick names/structure are sent, never account info. No separate ASC declaration needed since this doesn't touch the user's personal data.

---

## 5. App Review information

- **Sign-in required** → demo account already seeded on production: `applereview` / `review@fscombo.com` / `AppReview2026!` — has a saved preference ("Easy Warmup") and a generated combo. **Don't change its password** — App Review reuses it every submission.
- **Notes for review**: "FreestyleCombo lets users generate or build freestyle football trick combos, rate other users' public combos, and submit new tricks for review. Sign in with the demo account to see a saved preference and a generated combo under the Combos → Mine tab. No special hardware or account type is needed."
- **Contact**: your phone + email.

---

## 6. Pre-flight checklist

**Status (2026-08-27): backend + web live at fscombo.com; mobile not yet submitted.**

- [x] Production API reachable over HTTPS (`https://www.fscombo.com/api`)
- [x] Mobile release builds point at production (`kBaseUrl` in `api_client.dart`)
- [x] Privacy policy + terms pages live (`/privacy`, `/terms`)
- [x] Self-service account deletion shipped (API + web + mobile) — Apple Guideline 5.1.1(v)
- [x] App icon present (1024px)
- [x] Demo/review account seeded on production (`applereview`) — has a preference + a generated combo; **not yet approved to Public** since the account creating it isn't a production admin — approve via an existing prod admin account if you want the demo combo visible on the public tab too (optional, not required for review)
- [ ] Confirm Apple Developer Program is a **paid** membership (not just a free personal-team signing identity) and note the Team ID
- [ ] Set `DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj`
- [ ] Register the `com.rafaelffs.freestyleCombo` App ID in the Apple Developer portal (if not already)
- [ ] Create the app record in App Store Connect
- [ ] Capture screenshots (§3)
- [ ] Fill in listing metadata (§2) and App Privacy (§4) in App Store Connect
- [ ] `flutter build ipa --release`, upload via Xcode Organizer/Transporter
- [ ] TestFlight internal testing → external closed beta → full App Review
- [ ] Android/Play Store — not started
