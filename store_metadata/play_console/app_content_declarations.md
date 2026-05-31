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

- **Privacy policy URL:** `https://<owner>.github.io/<repo>/privacy.html`
  *(placeholder — replace with the live GitHub Pages URL once
  Pages is enabled, see docs/README.md)*

## App access

**Question:** Is all functionality in your app available without any
special access (e.g. login credentials, membership)?

- **Answer:** **All functionality is available without restrictions.**
- **Rationale:** Kultivar has no account system. Every feature is
  reachable from a fresh install. The Pro tiers are paid IAPs but
  they unlock additional capacity (unlimited plants etc.) — the
  *core functionality* remains available in the Free tier.

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
