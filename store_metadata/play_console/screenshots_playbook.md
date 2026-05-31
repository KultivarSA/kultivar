# Play Store screenshots — capture playbook

SR9 covers automated iOS screenshot capture via Fastlane snapshot
(see `ios/fastlane/`).  Android is intentionally manual — here is
why, plus the playbook for whoever runs a release.

## Why manual for Android?

Fastlane has `screengrab`, the Android analogue of `snapshot`, but
it requires an Espresso UI-test harness wired into the Flutter app.
Flutter's integration_test plugin can drive it, but the maintenance
burden is high — Espresso brittleness compounds with the Flutter
framework's frame-aware rendering.  Given Play only requires **2
screenshots minimum** (we ship 4–6) and the listing covers fewer
device classes than App Store Connect, the cost / benefit favours a
manual run.

## Minimum requirement per Play guidelines

| Device class       | Required | We ship  | Aspect ratio     |
| ------------------ | -------- | -------- | ---------------- |
| Phone              | 2        | 6        | 16:9 or 9:16     |
| 7-inch tablet      | 0        | 0        | —                |
| 10-inch tablet     | 0        | 0        | —                |
| Chromebook / large | 0        | 0        | —                |

Tablet slots are optional unless the app is listed as tablet-optimised
— which Kultivar is not in v1.

## Capture workflow

1. **Pick a clean emulator**.  Recommended: Pixel 8 Pro AVD running
   Android 14 (API 34).  This gives a 1440×3120 (~9:19.5) frame,
   which Play accepts and Mockuphone has device frames for.
2. **Wipe the emulator** before each capture session (Cold Boot in
   AVD Manager) so the first-launch onboarding fires.
3. **Tap "Explore with sample data"** on the welcome screen.  This
   triggers the SR8 demo seed — populated grid, completed runs,
   non-empty Costs and Analytics tabs.
4. **Walk the same 7 screens the iOS lane captures** so the listings
   stay visually parallel:

   1. `01_Home` — grow grid
   2. `02_PlantDetail` — top of detail with vital signs
   3. `03_PlantNotes` — scroll down to notes + photo timeline
   4. `04_Analytics` — yield-per-strain chart
   5. `05_HarvestArchive` — list of completed cycles
   6. `06_GrowReport` — open the PDF preview for the top archived run
   7. `07_Paywall` — Settings → Upgrade to Pro

5. **Capture each screen** with `Power + Volume Down` in the
   emulator (or the camera button in the emulator toolbar).  Files
   land at `~/.android/avd/<avd>/screenshots/`.
6. **Frame each shot** through [mockuphone.com](https://mockuphone.com/)
   if you want device-bezel framing.  Play accepts unframed PNGs
   too but framed shots have measurably better conversion in
   external A/B tests.
7. **Translate / re-capture per locale** by changing the emulator
   language under Settings → System → Languages → Add a language,
   then re-running the walk.  Repeat for:
   - en-ZA  (primary launch market)
   - en-US
   - de-DE
   - es-ES
   - fr-FR
   - it-IT
   - nl-NL
   - pt-PT
   - af-ZA
   - zu-ZA

8. **Drop the framed PNGs** into:
   ```
   store_metadata/android/<locale>/images/phoneScreenshots/
   ```
   Fastlane `supply` will pick them up on `fastlane supply --skip_upload_apk --skip_upload_aab`.

## Time budget

A single locale walk is ~6 minutes including framing.  10 locales
× 6 minutes ≈ 1 hour per release.  Worth it for the first launch;
if cadence picks up to monthly, revisit and wire screengrab.

## Why not just localise programmatically?

Some text in Play screenshots (the marketing overlays like "Track
every cycle" or "Generate sharable reports") is rendered through
the framing pipeline, not the app.  Kultivar v1 ships unframed
screenshots only — pure in-app pixels — so localisation is whatever
the app's locale picker resolves to.  When we add marketing overlays,
revisit.

## Per-locale onboarding hint

The Explore-with-sample-data button is localised — its label is
`Verken met voorbeelddata` in af-ZA and `Hlola ngemininingwane
yesibonelo` in zu-ZA.  Confirm the seed runs before capturing by
checking the Costs tab has expenses populated.
