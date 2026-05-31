# Kultivar — Android launch checklist

The literal "do these things this week" list for the Android-only
launch. Pairs with `LAUNCH.md` (strategy + 90-day plan); this doc is
the operational checklist.

**Status legend:**

- 🔴 = blocking — without this, you cannot ship
- 🟡 = required — must happen before public launch, schedulable
- 🟢 = nice-to-have — boosts launch but app ships without it
- ✅ = done

---

## 📅 Snapshot — 2026-05-31

Major infrastructure landed in the last 24 hours:

| | Item | Notes |
|---|---|---|
| ✅ | Domain `kultivar.io` | Cloudflare Registrar, ~$10/yr |
| ✅ | Domain `kultivar.co.za` (secondary, 308 → apex) | Afrihost, R75/yr |
| ✅ | Cloudflare DNS + orange-cloud proxy | SSL Full (strict), HSTS on |
| ✅ | Cloudflare Email Routing (inbound) | `support@kultivar.io` → personal Gmail |
| ✅ | Brevo SMTP (outbound) | `support@kultivar.io` sends with clean SPF/DKIM/DMARC |
| ✅ | GitHub organization `KultivarSA` | Public, owner = MarcoPolov |
| ✅ | GitHub repo `KultivarSA/kultivar` | Public, single clean initial commit |
| ✅ | Live website `https://kultivar.io` | GitHub Pages from `/docs`, edge-cached at Cloudflare's JNB + CPT POPs |
| ✅ | Privacy + Terms hosted at branded URLs | `/privacy.html`, `/terms.html` — Play Store requirement satisfied |
| ✅ | Favicon + apple-touch-icon | Browser tab + iOS home-screen bookmarks show the Kultivar dot |
| ⏳ | CIPC name reservation | Submitted; waiting 1-3 days for approval |

If everything 🔴 below is knocked off by Friday, you can submit to
Play Internal Testing by Monday.

---

## YOUR TODO LIST (things only you can do)

### 💰 Money + accounts (do this week)

These cost real money or take 24-48h to provision. Start now.

| | Item | Cost | Time | Where |
|---|---|---|---|---|
| 🔴 | **CIPC Pty Ltd registration** (after name approval) | R125 | 20 min | [eservices.cipc.co.za](https://eservices.cipc.co.za) or BizPortal |
| 🔴 | **Google Play Console** developer account | £25 (one-time) | 24-48h verification | [play.google.com/console](https://play.google.com/console) |
| 🔴 | **TymeBank Business account** (free, fully online) — after CIPC reg | R0 | 1 hour | [tymebank.co.za](https://www.tymebank.co.za/business) |
| 🔴 | **Tax info for Google** — SA tax certificate | R0 | 1 day | SARS eFiling |
| 🔴 | **RevenueCat account** (free tier) | R0 | 30 min | [revenuecat.com](https://www.revenuecat.com) |
| ✅ | ~~Domain `kultivar.io`~~ — done | — | — | — |
| ✅ | ~~Email `support@kultivar.io`~~ — done | — | — | — |

### 📱 Social handles (claim them all today — they're free)

🟡 Reserve every handle before someone else does. Even if you don't post
on TikTok for months, owning the name matters.

Recommended handles (matched to `kultivar.io` brand):

- [ ] Instagram `@kultivar.io` (fallback: `@kultivar.app`, `@kultivarapp`)
- [ ] TikTok `@kultivar.app`
- [ ] X / Twitter `@kultivarapp` or `@kultivar_app` (first one usually free)
- [ ] YouTube channel `Kultivar`
- [ ] Discord server (free — create it, you'll soft-open to public in
      Month 2)
- [ ] Reserve `r/kultivar` on Reddit (free — Reddit lets you create
      and sit on a subreddit without populating)
- [ ] Threads handle (Meta's account) — same handle as Instagram

### 🗣️ Native-speaker review (within 1 week)

🔴 The Zulu and Afrikaans ARB files (`lib/l10n/app_af.arb`,
`lib/l10n/app_zu.arb`) carry a `@@x-review-note` flag warning they
need native-speaker review before launch. Skipping this risks
embarrassing translation errors that one bad App Store review will
permanently anchor to your product.

- [ ] Post in r/SouthAfrica, r/Afrikaans, r/Zulu — offer R1000 / £50
      for a half-day review of ~180 strings each
- [ ] Alternative: post on UpWork / Fiverr with "South African,
      cannabis-aware, half day translation review"
- [ ] OR: ask a SA grower in your network — most growers know someone

Even 1 hour with a native speaker will catch the worst drift. Don't
ship without it.

### 📸 Screenshots (1-2 hours of your time)

🔴 Play requires minimum 2 phone screenshots per locale. We're shipping
6-7 per locale across 10 locales for a polished listing.

- [ ] Follow `store_metadata/play_console/screenshots_playbook.md`
- [ ] Pixel 8 Pro emulator, fresh boot, tap "Explore with sample data"
- [ ] Walk: Home → Plant Detail → Notes → Analytics → Archive →
      Grow Report → Paywall
- [ ] Repeat per locale (en-ZA, en-US, de-DE, es-ES, fr-FR, it-IT,
      nl-NL, pt-PT, af-ZA, zu-ZA) — ~6 min × 10 locales ≈ 1 hour
- [ ] Optionally frame through [mockuphone.com](https://mockuphone.com)
      for prettier listings
- [ ] Drop into `store_metadata/android/<locale>/images/phoneScreenshots/`

### 🔐 Android signing keystore (1 hour, mostly waiting)

🔴 Play won't accept the APK / AAB without it. **Critical: back up this
keystore in 3 separate places.** If you lose it, you can never push
updates to the same Play listing — you'd have to publish under a new
package name and lose all reviews and downloads.

See the **"Android signing setup"** section at the bottom of this doc
for the step-by-step. Claude can walk you through it interactively —
you just need to:

- [ ] Have a memorable password (you'll need it for every release)
- [ ] Decide where to back up the keystore file
      (recommended: 1Password / Bitwarden + encrypted USB + offline cold storage)
- [ ] Run the keystore-generation commands (covered below)

### 🧪 Internal testing (3-5 days before Day 0)

🔴 Get 5 trusted growers on the Internal Test track to walk through
onboarding → first plant → mock harvest. Catch friction before
strangers do.

- [ ] Identify 5 testers (Discord / Telegram / WhatsApp / friends-of-friends)
- [ ] Add their Gmail addresses as testers in Play Console
- [ ] Send them the Internal Test opt-in link (Play Console generates it)
- [ ] Watch their feedback land in your support email
- [ ] Patch any showstoppers; everything else goes to v1.0.1 backlog

---

## INFRASTRUCTURE STATUS (things already done or that Claude can finish)

Almost everything code-side is already shipping-ready.

### 🟢 Quick wins (under 5 min each)

- [ ] **Enable Cloudflare Web Analytics** for `kultivar.io` (free,
      privacy-friendly).  Cloudflare → kultivar.io → Analytics & Logs
      → Web Analytics → Enable.  Copy the generated beacon token, paste
      into the commented-out `<script>` block at the bottom of
      `docs/index.html` (search for `CLOUDFLARE_BEACON_TOKEN_PLACEHOLDER`),
      uncomment the block, commit + push.  Preflight script flags this
      placeholder as a TODO until activated.
- [ ] **Fill `<REVIEW_*>` placeholders** in
      `store_metadata/ios/en-US/review_information/` with your real
      contact info (deferred to iOS Month 2-3 but no harm doing now).
- [ ] **Fill `<COMPANY_REG_PLACEHOLDER>`** in `lib/legal/privacy_policy.dart`,
      `lib/legal/terms_of_service.dart`, `docs/index.html`, and
      `store_metadata/` once CIPC issues the registration number.
      Single find-replace, all surfaces in sync.

### ✅ Already done

- 95+ development tasks complete (see CHANGELOG.md for the full audit trail)
- 305 tests passing
- `flutter analyze` clean
- All 9 locales fully translated (Afrikaans + Zulu pending native-speaker review)
- Play store metadata files in `store_metadata/android/<locale>/`
  (title / short description / full description / changelog)
- Privacy Policy + Terms of Service pages generated and hosted at
  `docs/{privacy,terms}.html` — go live via GitHub Pages
- Pre-flight check script (`tools/preflight.ps1`) — runs 6 release gates
- Content rating answers + Data Safety form answers + Restricted
  Content cannabis declaration text pre-drafted in
  `store_metadata/play_console/app_content_declarations.md`
- In-app review prompt wired to fire after the first Grow Report share
- Auto ZAR currency for South Africa
- Africa/Johannesburg timezone smoke tests
- Sentry crash reporting (opt-in, gated by telemetry consent)
- Demo-data seed audited so reviewers see a populated app immediately

### 🟡 Still to wire (Claude can do — none blocking submission)

- [ ] **GitHub Pages activation** for the `/docs` folder so the
      Privacy + Terms URLs go public. Settings → Pages → Source =
      "Deploy from branch" → main / `/docs`. Verify the URLs in
      `lib/legal/privacy_policy.dart` + `terms_of_service.dart` match
- [ ] **Confirm app icon + adaptive icon** rendered through
      `flutter_launcher_icons` — open `android/app/src/main/res/`
      and eyeball the mipmap-* folders for visual consistency
- [ ] **Optional: write a `tools/release.ps1`** that bumps the
      version, generates the changelog, builds the AAB, and prints
      the upload steps — automates the bits that aren't already
      automated. ~30 min of work
- [ ] **Optional: integration test for the keystore-signed release
      build** — verifies the AAB compiles cleanly and is signed.
      ~20 min

---

## EXECUTION TIMELINE

### This week (Week T-2)

- 🔴 Open Google Play Console account (£25, allow 48h to provision)
- 🔴 Open RevenueCat account
- 🟡 Claim all social handles
- 🟡 Buy domain
- 🟡 Set up support email
- 🟡 Post native-speaker review request

### Next week (Week T-1)

- 🔴 Generate Android signing keystore (with Claude's help — see below)
- 🔴 Wire `android/key.properties` + `build.gradle` signing config
- 🔴 Run `pwsh ./tools/preflight.ps1` — all 6 checks PASS
- 🔴 Capture Android screenshots (~1 hour)
- 🔴 Build release AAB: `flutter build appbundle --release`
- 🟡 Submit to Play Internal Testing — invite 5 testers
- 🟡 Receive native-speaker feedback → patch ARB files

### Week 0 (Soft launch)

- 🔴 Patch testers' showstopper feedback
- 🔴 Set up RevenueCat products with ZAR pricing (Lifetime Local
      one-time + Pro Cloud monthly + annual)
- 🟡 Complete Play Console listing — paste all metadata, screenshots,
      content rating questionnaire, Data Safety form, Restricted
      Content declaration
- 🟡 Configure 20% staged rollout for production

### Day 0 (Tuesday)

- 🔴 Submit to Play Production track at 20% staged rollout
- 🟡 Wait 3-7 days for Play approval
- 🟡 Use the waiting time to pre-produce launch-day content (see
      LAUNCH.md week T-2 content stockpile)

### Day 1 (when Play goes public)

- Follow LAUNCH.md Day 1 channel mix
- Don't post in r/cannabis or major weed subs
- Save Product Hunt + Hacker News for iOS launch (Month 2-3)

---

## Android signing setup (~1 hour)

A more detailed walkthrough than the inline `LAUNCH.md` reference.
These commands work in Windows PowerShell with the JDK from your
Flutter install (`flutter doctor` will confirm Java is on PATH).

### Step 1: Generate the keystore

In the project root, in PowerShell:

```powershell
# Pick a directory OUTSIDE the project root for the keystore.
# Never commit a keystore to git.
$keystorePath = "$env:USERPROFILE\.android\kultivar-upload.jks"

keytool -genkey -v `
  -keystore $keystorePath `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias kultivar-upload
```

You'll be prompted for:

- A keystore password — **invent a strong one and save it to your
  password manager NOW**
- A key password — use the same as the keystore password (Android
  Studio convention; keeps signing simple)
- Your name, organisational unit, city, state, country code (ZA) —
  these go into the certificate. Use real values

### Step 2: Wire the keystore into Gradle

Create `android/key.properties` (DO NOT COMMIT — already in .gitignore
via the env.json pattern, but double-check):

```properties
storePassword=<the password you just set>
keyPassword=<same password>
keyAlias=kultivar-upload
storeFile=C:\\Users\\<your-username>\\.android\\kultivar-upload.jks
```

Then in `android/app/build.gradle`, add **before** the `android {`
block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

And inside the `android {` block, add:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### Step 3: Test the release build

```powershell
flutter build appbundle --release
```

Output lands at `build/app/outputs/bundle/release/app-release.aab`.
This is the file you upload to Play Console.

### Step 4: Back up the keystore THREE places

🚨 **If you lose the keystore, you cannot ship updates to this Play
listing ever again.** You'd have to publish under a new package name
and forfeit all reviews + installs.

Recommended backup pattern:

1. **Password manager** (1Password, Bitwarden, etc.) — store the
   `.jks` file as an attachment plus the password as a secure note
2. **Encrypted USB drive** kept physically separate from your dev
   machine
3. **Cloud cold storage** — Backblaze B2, encrypted zip, or similar.
   NOT in your synced cloud drive (one compromised laptop and it's
   gone)

Optional 4th: print the keystore base64'd onto paper, sealed in an
envelope with a trusted person. Paranoid but for a £30k+ ARR business
this is the right level of caution.

---

## When you're stuck

- **Keystore generation fails** — usually a Java path issue. Run
  `keytool -help` in PowerShell to confirm it's on your PATH; if
  not, find Java via `flutter doctor -v` and add its `bin/` to PATH
- **`flutter build appbundle` fails with `Execution failed for task
  ':app:signReleaseBundle'`** — keystore path in `key.properties`
  is wrong, or the password doesn't match. Re-check with `keytool
  -list -v -keystore <path>`
- **Play Console rejects with "Restricted Content"** — re-paste the
  declaration verbatim from `store_metadata/play_console/app_content_declarations.md`.
  Do not improvise. Their NLP triggers on certain phrasings
- **First-submission rejection in general** — Play's appeal flow is
  fast and reasonable. Reply to the rejection email citing the Cannabis
  for Private Purposes Act 7 of 2024 (SA) or your jurisdiction's
  equivalent. 80%+ of cannabis-tracker rejections clear on first appeal

---

## After Day 1: what success looks like in the first 30 days

| Metric | Floor | Stretch |
|---|---|---|
| Total Android installs | 500 | 3,000 |
| SA share of installs | 40% | 60% |
| Play store rating | 4.0 ★ (10 reviews) | 4.5 ★ (50 reviews) |
| Crashes / 1000 installs | < 5 | < 1 |
| D7 retention | 30% | 50% |
| Free → Pro conversion | 1.5% | 4% |
| Native-speaker fixes shipped | 1 (af + zu polish) | 2 |
| Bug-fix releases shipped | 2 | 4 |

If floor is hit comfortably: trigger the iOS phase per LAUNCH.md
Month 2-3.

If floor is missed: investigate WHY before trying to fix it. Usually
either the value prop isn't translating in store listing copy
(easy fix — A/B the description) or the price point isn't right
(harder fix — paywall data).

---

*Last updated: 2026-05-30. This document gets edited as you cross
items off — keep the most recent state in git so you can always
trace back what shipped when.*
