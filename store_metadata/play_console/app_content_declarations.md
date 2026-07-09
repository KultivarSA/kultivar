# Google Play Console — App Content declarations

Google Play doesn't have a single "review notes" textarea like App
Store Connect does. Instead it has a series of structured
declarations under **Policy → App Content** that you submit *once*
per app and update only when the answers change. This file documents
the answers Kultivar 1.0 ships with.

Cross-check this file against the live Play Console screens before
each release — Google occasionally adds new questions; the document
should track them.

## Privacy Policy

**Status required:** Yes

- **Privacy policy URL:** `https://kultivar.io/privacy.html`
- **Terms of service URL:** `https://kultivar.io/terms.html`

## App access (Sign in details)

**Question (2026 wording):** Is any part of your app restricted?
Google's expanded definition counts *payments (one-time products,
subscriptions, access tiers)* and *biometric authentication* as
restrictions — both apply to Kultivar.

- **Answer:** **Yes** — because of (1) the paid tiers (Lifetime
  Local one-time product + Pro Cloud subscription gate capacity,
  full analytics history, widget, community benchmarks) and (2) the
  optional biometric App Lock.  Kultivar has **no sign-in / no
  accounts** of any kind.
- **Instruction name:** "Paid tiers + optional App Lock (no sign-in
  exists)".  Username/password: not applicable.
- **Instructions text (paste):** no sign-in exists; core journaling
  is fully free; paid tiers purchase through standard Google Play
  Billing via Settings → Subscription → Upgrade; App Lock
  (biometric/PIN) is OFF by default and user-enabled only — a fresh
  install is never locked; tap "Explore with sample data" on the
  welcome screen to load the full feature surface in <30 s with no
  registration or payment.
- **History:** the original draft answered "All functionality is
  available without restrictions" against Google's older wording.
  The 2026 form explicitly lists payments/access tiers and biometric
  auth as "Yes" triggers, so answering No would be a declaration
  mismatch against a visible paywall + three Play Billing products.

## Ads

- **Answer:** **My app does not contain ads.**
- **Rationale:** No ad SDKs, no banner network, no ad-related event
  tracking. Confirmed: grep the codebase for "AdMob", "Mobvista",
  "Unity Ads" etc. — zero hits.

## Content rating

Use Google's IARC questionnaire under **Policy → App Content → Content rating**. Suggested answers:

- **Reference to cannabis / drugs:** Yes — clinical / educational
  context (the app references cannabis cultivation directly).
- **Violence:** None.
- **Sexual content:** None.
- **Profanity:** None.
- **Crude humour:** None.
- **Gambling:** None.
- **Online interactivity:** Minimal (opt-in anonymous yield
  benchmarking; no user-to-user messaging; no chatrooms).

Expected IARC rating: **PEGI 18 / Teen+ / Mature 17+** depending on
region. Aligns with comparable cannabis-tracking apps in Play.

## Target audience and content

- **Target age group:** **18+** *(adults only — the entire premise
  of the app)*.
- **Age verification:** Not required by Google for 18+ apps unless
  payment is involved at sign-up. Kultivar has no sign-up.
- **App appeal to children:** **No.** UI vocabulary, content
  domain, and brand presentation are explicitly adult-grower-focused.

## Data safety

This is the most detailed section. Match these answers in the form:

### Data collection

- **Does your app collect or share any of the required user data
  types?** Yes (very small amount, all opt-in).

### Data types

For each row below, declare in the form.

| Data type | Collected? | Shared? | Purpose | Optional? |
|---|---|---|---|---|
| Crash logs | Yes | Yes (Sentry) | App functionality, Analytics | **Yes — opt-in via in-app consent sheet (SR6)** |
| Diagnostics (performance) | Yes | Yes (Sentry) | App functionality, Analytics | **Yes — opt-in via in-app consent sheet** |
| Purchase history | No | No | — | — *(RevenueCat handles entitlement validation; we don't store purchase events)* |
| User-generated grow data (plant names, notes, photos) | **No** | No | Local only | — |
| Anonymous yield benchmarks | **Yes** | Yes (Supabase) | App functionality | **Yes — opt-in via Settings + Pro Cloud tier** |
| Personally identifiable info (name, email, etc.) | **No** | No | — | — *(no account system)* |
| Financial info | No | No | — | — |
| Health & fitness | No | No | — | — |
| Messages | No | No | — | — |
| Photos and videos | **Locally only** | No | App functionality | — |
| Audio files (voice notes) | **Locally only** | No | App functionality | — |
| Files and docs | No | No | — | — |
| Calendar / Contacts | No | No | — | — |
| App activity (interactions, screens viewed) | Yes | Yes (Sentry) | App functionality | **Yes — opt-in** |
| Device or other IDs | No | No | — | — |

### Security practices

- **Encrypt data in transit:** Yes (HTTPS for Supabase, Sentry,
  RevenueCat, Open-Meteo).
- **Provide a way to request data deletion:** Yes — Settings →
  Clear all data wipes every local datum (no remote profile exists
  to delete).
- **Independent security review:** Not yet — small indie app, no
  third-party audit performed. Re-evaluate post-launch if user
  base grows.
- **Compliant with Google Play Families Policy:** N/A — 18+ only.

## Government apps

- **Answer:** Not a government app.

## Financial features

- **Answer:** Not a financial-services app.

## Health features

- **Answer:** **Does not provide medical information or interpret
  user-supplied health data.** Although users may track personal
  cannabis consumption *qualitatively* (effects ratings on harvests),
  Kultivar does not give medical advice, dose recommendations, or
  drug-interaction warnings. The in-app disclaimer makes this
  explicit ("not for medical advice").

## News apps

- **Answer:** Not a news app.

## COVID-19 contact tracing

- **Answer:** Not a contact-tracing app.

## Restricted content — Cannabis declaration

This is the critical section for our category. Google Play
**permits** apps that "facilitate the sale of marijuana or
marijuana products" only in approved jurisdictions, but
**Kultivar does not facilitate any sale** — we are a tracking
journal only.

- **Does your app sell or facilitate the sale of cannabis or
  cannabis-related products?** **No.**
- **Does your app provide cannabis-related content (information,
  growing tips, strain reference)?** **Yes — informational only.**

Suggested supporting text for the declaration's free-text field:

> Kultivar is a private grow-cycle journal for adult home growers
> in jurisdictions where cannabis cultivation is legal (e.g. South
> Africa under the Cannabis for Private Purposes Act 7 of 2024,
> Canada, the legal-cultivation U.S. states, several EU members).
> The app does not facilitate the sale, delivery, marketplace, or
> social distribution of cannabis. It is a personal record-keeping
> tool comparable to Google Play–approved apps like GrowBuddy,
> Plant Diary, and Strain Genie.

## Released countries / regions

Apply the same jurisdictional sanity check Apple does: ship to
countries where private adult cultivation is at least *tolerated*
or legal. Avoid releasing into countries with active criminal
enforcement (UAE, Saudi Arabia, Singapore, etc.) — Google will
permit the listing but the app may be flagged by local users.

Suggested initial launch set: AU, AT, BE, CA, CH, CZ, DE, ES, FR,
GB, IE, IT, LU, MT, NL, NZ, PT, US, ZA.

## What's new (release notes)

These pull from `store_metadata/android/<locale>/changelogs/<versionCode>.txt`.
Make sure that file is filled before each release.

---

## Reviewer Notes (human-reviewer-facing)

Play Console doesn't have a dedicated "review notes" textarea like
App Store Connect does. Use this block in two places:

1. **As-is in the "Restricted Content — Cannabis declaration"
   free-text field** when filling out the App Content questionnaire.
2. **As the body of any first-rejection appeal email** Google
   sends — see the Appeal Template at the bottom of this file.

The text is deliberately structured so a non-lawyer reviewer can
trace each claim back to a verifiable source.

### Block — paste verbatim

> **What Kultivar is:**
> Kultivar is a private, on-device journal for adult home cannabis
> growers. It is a record-keeping tool for plant lifecycle events
> (seed, vegetative, flower, harvest, dry, cure) and post-harvest
> outcomes (yield, quality ratings). All user data is stored
> locally on the device by default.
>
> **What Kultivar is not:**
> Kultivar does not facilitate the sale, marketplace, social
> distribution, delivery, or peer-to-peer exchange of cannabis or
> cannabis-related products. There are no payment flows for
> physical goods, no in-app marketplace listings, no user-to-user
> messaging, no chat, no social feed. The app contains zero
> instructional content that promotes consumption to minors.
>
> **Legal basis for distribution:**
> The app is targeted at jurisdictions where private adult cannabis
> cultivation is lawful or expressly decriminalised, including:
>
> - **South Africa** — Cannabis for Private Purposes Act, Act 7
>   of 2024 (assented 28 May 2024). Sections 2–4 permit cultivation
>   of a prescribed quantity of cannabis plants by an adult for
>   personal consumption in a private place. Kultivar's feature set
>   (plant inventory, lifecycle tracking, personal-use yield
>   recording) maps directly to the legitimate use cases that Act
>   protects.
> - **Canada** — Cannabis Act, S.C. 2018, c. 16, s. 12 (personal
>   cultivation of up to four plants per dwelling-house).
> - **United States** — 24 states + D.C. permit some form of adult
>   personal cultivation (state-by-state).
> - **European Union** — Germany (CanG, 1 April 2024), Malta (Cap.
>   633, 2021), Luxembourg (2023), the Netherlands (tolerated).
>
> **Comparable apps already approved on Google Play:**
> GrowBuddy, Plant Diary, Bud Tracker, Strain Genie, Greenbox. All
> ship cannabis grow-tracking functionality in the same Lifestyle
> / Productivity categories and are publicly distributed on Play.
>
> **Demo data:**
> Tap "Explore with sample data" on the welcome screen to load six
> completed grow cycles, populated environment logs, and a strain
> library. No registration required, no payment required, the
> entire feature surface is reachable in <30 seconds.

---

## Appeal Template (use if Play rejects the first submission)

Cannabis-tracker apps reach manual review even when policy is
explicit. The first reviewer sometimes flags the app under the
"Restricted Content — Marijuana" clause without reading the
declaration. Replying calmly with the template below clears
80%+ of first-pass rejections within 1–3 business days (per
LAUNCH_ANDROID.md historical notes).

### Template — paste into the rejection-reply email

> Dear Google Play Review Team,
>
> Thank you for the review of [io.kultivar.app — Kultivar — Grow
> Cycle Tracker], submitted on [date]. I'm writing to request a
> re-review under the Restricted Content — Marijuana policy.
>
> Kultivar is a **private grow-cycle journal** for adult home
> growers. It does not facilitate any of the activities prohibited
> under the Marijuana policy:
>
> - **No sale or marketplace:** The app has no payment flow for
>   physical cannabis goods. The only in-app purchases are
>   subscription tiers that unlock journaling features (unlimited
>   plant entries, sync, etc.) — purchased through Google Play
>   Billing.
> - **No delivery facilitation:** No address fields, no order
>   forms, no courier integrations.
> - **No social distribution:** No user-to-user messaging, no
>   chat, no feed, no comments.
> - **No promotion to minors:** The app is declared 18+ in the
>   Target Audience section. The UI vocabulary, brand voice, and
>   marketing copy are aimed exclusively at adult home growers in
>   legal jurisdictions.
>
> The app is legal in the launch markets:
>
> - **South Africa** — Cannabis for Private Purposes Act, Act 7
>   of 2024 (signed 28 May 2024). Personal cultivation is lawful
>   for adults in a private place.
> - **Canada** — Cannabis Act, S.C. 2018, c. 16, s. 12.
> - **Germany** — CanG (Cannabisgesetz), 1 April 2024.
> - Other launch jurisdictions listed in the App Content
>   declaration.
>
> Comparable apps **currently distributed on Google Play** include
> GrowBuddy, Plant Diary, Bud Tracker, Strain Genie, and Greenbox.
> All ship the same core feature set (plant tracking, harvest
> logging) in the same lawful jurisdictions.
>
> To verify the app's actual behaviour, tap **"Explore with sample
> data"** on the welcome screen. The full feature surface
> populates in under 30 seconds with six demo grow cycles. No
> registration is required.
>
> I'd be grateful for a second review. Happy to provide further
> documentation, legal-counsel correspondence, or jurisdictional
> evidence if it would help.
>
> Sincerely,
> Marco-Paul Van Niekerk
> Kultivar SA Pty Ltd (CIPC reg 2026/429365/07)
> support@kultivar.io

---

## Submission day checklist

The night before you click "Submit for review":

- [ ] Privacy + Terms URLs return 200 (currently `https://kultivar.io/privacy.html` and `/terms.html`)
- [ ] Feature graphic uploaded (`store_metadata/android/en-US/images/featureGraphic.png`)
- [ ] All 7 phone screenshots uploaded (`store_metadata/android/en-US/images/phoneScreenshots/`)
- [ ] Title / short / full description pulled from `store_metadata/android/en-US/`
- [ ] Cannabis declaration free-text field has the **Reviewer Notes** block above pasted verbatim — DO NOT IMPROVISE
- [ ] App Content questionnaire all green ticks
- [ ] Internal testing release rolled out + at least 2 testers confirmed install works
- [ ] Signed AAB at `build/app/outputs/bundle/release/app-release.aab` (re-run `flutter build appbundle --release` if pubspec changed)
- [ ] versionCode in pubspec.yaml matches the AAB you uploaded
- [ ] Production release set to "Managed publishing" if you want a buffer between approval and going live
