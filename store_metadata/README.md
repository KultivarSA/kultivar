# Store metadata

Localised copy + assets for the App Store and Google Play store listings.
Follows the [Fastlane `supply`](https://docs.fastlane.tools/actions/supply/)
(Android) and [`deliver`](https://docs.fastlane.tools/actions/deliver/)
(iOS) directory schemas so the standard tooling can publish straight
from this folder.

## Structure

```
store_metadata/
├── android/
│   └── <locale>/                      e.g. en-US, de-DE, ...
│       ├── title.txt                  ≤ 50 chars
│       ├── short_description.txt      ≤ 80 chars
│       ├── full_description.txt       ≤ 4000 chars
│       └── changelogs/
│           └── <versionCode>.txt      ≤ 500 chars (Play release notes)
└── ios/
    └── <locale>/                      e.g. en-US, de-DE, ...
        ├── name.txt                   ≤ 30 chars  (app name)
        ├── subtitle.txt               ≤ 30 chars  (App Store subtitle)
        ├── description.txt            ≤ 4000 chars
        ├── keywords.txt               ≤ 100 chars (comma-separated)
        ├── promotional_text.txt       ≤ 170 chars (editable post-launch
        │                                without resubmitting binary)
        └── release_notes.txt          ≤ 4000 chars (per-version notes)
```

## Locales shipped

Matches the Flutter app's i18n coverage (`lib/l10n/app_*.arb`):

| Code | Language | Android folder | iOS folder |
|---|---|---|---|
| `en` | English (US) | `en-US` | `en-US` |
| `de` | German | `de-DE` | `de-DE` |
| `es` | Spanish (Spain) | `es-ES` | `es-ES` |
| `fr` | French (France) | `fr-FR` | `fr-FR` |
| `it` | Italian | `it-IT` | `it-IT` |
| `nl` | Dutch | `nl-NL` | `nl-NL` |
| `pt` | Portuguese (Portugal) | `pt-PT` | `pt-PT` |
| `af` | Afrikaans (South Africa) | `af-ZA` | *(see note)* |
| `zu` | isiZulu (South Africa) | `zu-ZA` | *(see note)* |

> **iOS note:** Apple's App Store metadata schema only supports
> Afrikaans on macOS/iOS as of 2025 — there's no `af-ZA` slot in
> App Store Connect for app descriptions yet, and **isiZulu is not
> on Apple's supported metadata locales list at all**.  Both SA
> languages are still rendered correctly *inside* the running app
> (Flutter / `MaterialApp.supportedLocales` doesn't depend on
> store metadata), but the store-listing copy itself falls back to
> the English description on iOS for SA users.  Play Store supports
> both — fill `store_metadata/android/af-ZA/` and
> `store_metadata/android/zu-ZA/` when ready.

## Translation provenance

The English copy is the canonical source. The six other languages were
adapted from the English source with care to preserve the marketing
tone and feature claims. **Before each public release, the affected
locales should be reviewed by a native speaker** — especially the
App Store keyword sets (`keywords.txt`), which carry significant search
ranking weight and benefit from local idiom.

Common mistakes the review pass catches:

- Cannabis-specific terminology that doesn't translate literally
  ("trichome", "flush", "veg", "bloom" — most languages either
  loanword them or use a specific local term).
- Apple's house-style rules per locale (e.g. German uses "Du" for
  consumer apps, French uses "vous" by default).
- Pluralisation in feature counts (some locales need a separate
  string for `1 plant` vs `2 plants`).

## Updating for a new release

```sh
# 1. Edit the source files for any feature claims that have changed
#    (use store_metadata/android/en-US/full_description.txt as the
#    canonical source).
#
# 2. Mirror the change across the six other locales — re-translate
#    only the bits that changed; everything else stays.
#
# 3. Drop a per-version Play changelog (≤ 500 chars):
#      store_metadata/android/<locale>/changelogs/<versionCode>.txt
#    versionCode is the `+N` after `pubspec.yaml`'s version (so
#    `1.0.0+1` → file `1.txt`).
#
# 4. Replace the iOS release_notes.txt with the latest copy for each
#    locale — App Store Connect overwrites the previous version's
#    notes on each submission.

# 5. (If using Fastlane) push to the stores:
cd android && fastlane supply --skip_upload_apk --skip_upload_aab
cd ../ios && fastlane deliver --skip_binary_upload
```

## Character-count cheatsheet

| File | Hard cap | Soft target |
|---|---|---|
| iOS `name.txt` | 30 | 12 (matches `Kultivar`) |
| iOS `subtitle.txt` | 30 | 25–30 (use every char) |
| iOS `keywords.txt` | 100 | 95–100 (every char ranks) |
| iOS `promotional_text.txt` | 170 | 150–170 |
| Play `title.txt` | 50 | 30–50 |
| Play `short_description.txt` | 80 | 75–80 |
| Play `changelogs/N.txt` | 500 | 250–400 |
| iOS / Play long description | 4000 | 2500–3500 (top of fold gets the click) |
