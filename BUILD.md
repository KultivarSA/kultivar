# Building Kultivar

## Quick start (local dev)

1. Copy `env.example.json` to `env.json` at the project root.
2. Fill in your Supabase project URL and anon key. Get them from
   <https://app.supabase.com> → your project → **Settings → API**.
3. Run the app with the env file loaded:

   ```sh
   flutter run --dart-define-from-file=env.json
   ```

   For your IDE: add `--dart-define-from-file=env.json` to the run
   configuration arguments (VS Code: `.vscode/launch.json` → `args`,
   Android Studio: Run Configurations → "Additional run args").

## Without Supabase credentials

The app runs fine without `env.json`. The community-stats panels in
Strain Detail simply show nothing, and benchmark submissions silently
no-op. Everything else (plants, grow logs, notes, harvests, expenses,
weather, notifications) works fully offline.

## Production / CI builds

Never commit `env.json`. Instead, inject the values via your CI runner:

### GitHub Actions example

```yaml
- name: Build APK
  run: |
    flutter build apk --release \
      --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
      --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

### Codemagic / Bitrise / Fastlane

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` as encrypted environment
variables in the CI dashboard, then reference them in the build step
the same way as above.

## Release pipeline

Two scripts, run in order: `preflight.ps1` (verify clean state) →
`release.ps1` (ship).

### `pwsh ./tools/preflight.ps1`

Six gates in order, ASCII output, exits with the number of failed
checks (0 = ready):

1. `flutter analyze` clean
2. `flutter test` green (currently 305 tests)
3. ARB key parity — every locale covers every `app_en.arb` key
4. No `<*_PLACEHOLDER>` markers left in `store_metadata/`, `lib/legal/`,
   or `docs/`
5. CHANGELOG `[Unreleased]` block non-empty (catches forgot-to-roll-header)
6. `pubspec.yaml` version bumped vs. latest git tag (warns, doesn't fail)

Run this any time you want to confirm shipping state. CI calls it
on every PR.

### `pwsh ./tools/release.ps1`

End-to-end release pipeline. Eight stages:

0. Working tree must be clean (no uncommitted changes)
1. Runs preflight as a gate — fails the release if any check fails
2. Bumps `pubspec.yaml` version: prompts you with patch / minor / major
   suggestions or accepts `-Version 1.0.1` explicitly. Build number
   auto-increments
3. Rolls `CHANGELOG.md` — renames `[Unreleased]` to
   `[X.Y.Z] - YYYY-MM-DD` and starts a fresh empty `[Unreleased]` block
4. Commits both files as `Release vX.Y.Z`
5. Builds the release AAB (`flutter build appbundle --release`)
6. Tags the commit as `vX.Y.Z` (does NOT push — you push when ready)
7. Prints the upload checklist + AAB path

Flags:

| Flag | Effect |
|---|---|
| `-Version 1.0.1` | Skip the interactive prompt |
| `-DryRun` | Print the plan; mutate nothing |
| `-SkipPreflight` | Skip step 1 (never in CI) |
| `-SkipGitClean` | Skip step 0 (don't use this — release without commit history is unsafe) |

Typical use:

```powershell
# Verify state
pwsh ./tools/preflight.ps1

# Dry-run to confirm what the release will do
pwsh ./tools/release.ps1 -Version 1.0.1 -DryRun

# Actually ship
pwsh ./tools/release.ps1

# Output AAB lands at: build/app/outputs/bundle/release/app-release.aab
# Drag-and-drop into Play Console Internal Testing or Production
```

Both scripts are ASCII-only PowerShell so they run cleanly under
Windows PowerShell 5.1 without needing a UTF-8 BOM or a pwsh 7+
install. CI runners with `flutter` on `PATH` can call them directly.

## Versioning and releases

Kultivar follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
end-to-end: marketing version, git tags, and the App Store / Play Store
`versionName` all stay aligned. The Android `versionCode` and iOS
`CFBundleVersion` increment monotonically alongside, independent of the
semver line.

### When to bump what

| Change | Bump | Example |
|---|---|---|
| Bugfix, copy tweak, internal refactor | **PATCH** | `1.0.0 → 1.0.1` |
| New feature, additive UI, dependency upgrade | **MINOR** | `1.0.1 → 1.1.0` |
| Breaking data-model change, paid-tier reshuffle, removed feature | **MAJOR** | `1.1.0 → 2.0.0` |
| Any binary that goes to Apple / Google | **+build** | `1.0.0+1 → 1.0.0+2` |

The build number (`+N` suffix in `pubspec.yaml`) is *never* reused —
even an identical-source rebuild gets `+N+1` because the stores reject
re-uploads of the same `versionCode` / `CFBundleVersion`.

### Cut process

```sh
# 1. Bump version in pubspec.yaml
#    e.g. 1.0.0+1  →  1.1.0+2     (minor release, new build)

# 2. Promote [Unreleased] to a numbered section in CHANGELOG.md
#    with today's date.  Add a fresh empty [Unreleased] above it.

# 3. Commit + tag with a `v`-prefix matching the marketing version
git add pubspec.yaml CHANGELOG.md
git commit -m "release: 1.1.0"
git tag -a v1.1.0 -m "Kultivar 1.1.0"
git push origin main --tags

# 4. CI workflow on the v* tag builds release artefacts + uploads to
#    App Store Connect / Play Internal Testing track.
```

### Tag scheme

- `v<MAJOR>.<MINOR>.<PATCH>` — public release (e.g. `v1.2.0`).
- `v<MAJOR>.<MINOR>.<PATCH>-rc.<N>` — release candidate (e.g.
  `v1.2.0-rc.1`); pushed to internal / TestFlight tracks only, not
  promoted to production until the `v1.2.0` tag lands.
- Pre-release tags use Sentry's environment marker `pre-release` so
  crash reports stay grouped separately from production.

### Pre-release checklist

1. `flutter analyze` clean
2. `flutter test` 100% passing (currently 283+ tests; never regress)
3. CHANGELOG.md `[Unreleased]` section captures every user-visible
   change since the last tag — copy-edit for end-user voice (not
   internal jargon like "Q11 collection tests")
4. `pubspec.yaml` version + build numbers bumped
5. Store metadata under `store_metadata/` updated if any feature copy
   needs to change (see `store_metadata/README.md` for the schema)
6. Smoke test on a real device for each target platform — at minimum
   a fresh install, restoring a backup, and the full grow lifecycle
   from plant creation through curing completion
7. **Notification on-device regression** (every release after UP1,
   the flutter_local_notifications 17→21 upgrade) — the plugin's
   platform-channel side isn't exercised by the unit test suite, so
   each release run-through must include:
   - Snooze a care reminder → verify it re-fires after the configured
     snooze window (Settings → snooze duration)
   - Schedule a target-harvest reminder ≥ 8 days out → fast-forward
     the device clock or use a near-future date and confirm both the
     7-day-before and 1-day-before slots fire
   - Trigger a drying-complete and curing-complete notification path
     by completing those lifecycle steps with end-dates set to the
     near future
   - Test the burping-reminder week-1 / week-2 / week-3 cadences
     (the schedule param drives the body copy + repeat interval)
   - Verify Android 13+ POST_NOTIFICATIONS permission prompts on a
     fresh install
   - On iOS, verify the snooze action button appears on the swipe-down
     notification (DarwinNotificationCategory `care_snooze`)

## Tests

```sh
flutter test                # 50+ unit tests
flutter test --coverage     # with lcov coverage in coverage/lcov.info
```

CI runs the same on every push / PR via `.github/workflows/test.yml`.
See `test/README.md` for the layout and where to add new coverage.

## Legal pages (hosted)

App Store §1.5 and Play's Data Safety policy both require a
publicly-accessible Privacy Policy URL on the store listing.  The
in-app version (Settings → Legal) satisfies the *in-app* requirement
but not the listing URL.

`tools/generate_legal_html.py` reads the same markdown constants the
in-app viewer uses (`lib/legal/privacy_policy.dart` +
`lib/legal/terms_of_service.dart`) and emits styled static HTML into
`/docs`.  Single source of truth — when the in-app policy changes,
re-run the generator and both surfaces update together.

```sh
python tools/generate_legal_html.py
```

Output:

- `docs/index.html` — landing page
- `docs/privacy.html` — Privacy Policy
- `docs/terms.html` — Terms of Service
- `docs/README.md` — GitHub Pages setup notes

### Enabling GitHub Pages

One-time setup in repo settings:

1. **Settings → Pages**
2. **Source:** Deploy from a branch
3. **Branch:** `main` · **Folder:** `/docs`

URLs become available at
`https://<owner>.github.io/<repo>/{privacy,terms}.html` within ~30 s.
Use those URLs in:

- App Store Connect → App Privacy → Privacy Policy URL
- Google Play Console → Store presence → Main store listing → Privacy
  Policy
- `store_metadata/` long-description bodies that reference the policy

For a custom domain (`kultivar.app` etc.), add a `CNAME` file in
`/docs` and configure DNS per GitHub Pages instructions.

## App Review / Data Safety prep

Cannabis-tracking apps draw extra scrutiny under Apple §1.4.3 and
Google Play's Restricted Content policy. `store_metadata/` ships
pre-drafted answers so submission day isn't a research session.

### Apple — App Review Information

Lives under
`store_metadata/ios/<locale>/review_information/`. Mirrors Fastlane
`deliver`'s expected layout: `notes.txt` is the textarea that lands
in App Store Connect → App Information → Review Notes. Per-locale
folders (en-US / af-ZA / zu-ZA) cover the launch markets.

Fill these placeholders before submission:

- `first_name.txt`, `last_name.txt`, `email_address.txt`,
  `phone_number.txt` — the contact Apple uses if they have
  questions during review.
- `<PRIVACY_URL_PLACEHOLDER>` and `<REVIEW_CONTACT_EMAIL_PLACEHOLDER>`
  inside `notes.txt` — replace with the live GitHub Pages privacy
  URL and your support email.

### Apple — App Privacy ("nutrition label")

Pre-drafted at `store_metadata/ios/app_privacy_answers.md`. Walks
through each App Store Connect privacy category with the Kultivar
1.0 answer and rationale. Update whenever a new data flow ships
(e.g. when cross-device sync lands).

### Google Play — App Content + Data Safety

Pre-drafted at `store_metadata/play_console/app_content_declarations.md`.
Walks through every Play Console **App Content** section (privacy
policy, app access, ads, content rating, target audience, data
safety, restricted-content cannabis declaration) with our answers
and the supporting copy.

### Pre-submission checklist (App Store specifically)

1. `flutter analyze` clean, `flutter test` 100% (current: 295/295).
2. Sentry DSN configured (`--dart-define=SENTRY_DSN=...`) if you
   want crash reports; otherwise leave unset.
3. Review notes contacts filled
   (`store_metadata/ios/<locale>/review_information/`).
4. `<PRIVACY_URL_PLACEHOLDER>` and `<REVIEW_CONTACT_EMAIL_PLACEHOLDER>`
   replaced inside `notes.txt`.
5. App Privacy nutrition label populated per
   `store_metadata/ios/app_privacy_answers.md`.
6. Screenshots captured + uploaded — see "Screenshots" below.
7. Encryption export compliance answered:
   `ITSAppUsesNonExemptEncryption = false` in `Info.plist`.

### Pre-submission checklist (Google Play specifically)

1. Same first two items (`analyze`, `test`).
2. App Content section completed per
   `store_metadata/play_console/app_content_declarations.md`.
3. Cannabis declaration submitted under Restricted Content with
   the supporting copy from the same file.
4. Data Safety form completed — every "Yes" in the answers file
   must have its optional/required flag set.
5. Screenshots captured manually per
   `store_metadata/play_console/screenshots_playbook.md`.

## Screenshots (SR9)

iOS captures are fully automated.  Play captures are manual but
documented end-to-end.

### iOS — Fastlane snapshot

Configuration lives in `ios/fastlane/`:

| File                              | Purpose                                |
| --------------------------------- | -------------------------------------- |
| `ios/fastlane/Fastfile`           | `screenshots`, `upload_screenshots`, and `screenshots_and_upload` lanes |
| `ios/fastlane/Snapfile`           | Device classes (iPhone 16 Pro Max, iPhone 16 Plus, iPad Pro 13" M4) + 9 locales |
| `ios/RunnerUITests/RunnerUITests.swift` | XCUITest driver — walks Home → Plant Detail → Notes → Analytics → Archive → Grow Report → Paywall |

**First-run setup (one-time per machine):**

```bash
cd ios
bundle install                  # if you use Bundler for fastlane
fastlane snapshot init          # writes SnapshotHelper.swift next to RunnerUITests.swift
```

Then open `ios/Runner.xcworkspace` once in Xcode and add the
`RunnerUITests` target if it isn't already present (File → New →
Target → UI Testing Bundle, name it `RunnerUITests`).  Drag the
existing `RunnerUITests.swift` into the target so it compiles.

**Capture + upload:**

```bash
cd ios
fastlane screenshots            # captures only — ~25 min for 3 devices × 9 locales
fastlane upload_screenshots     # pushes to App Store Connect (needs API key)
# or in one go:
fastlane screenshots_and_upload
```

Captured PNGs land in `ios/fastlane/screenshots/<locale>/` and are
git-ignored — they're rebuilt from the running app each release.

The XCUITest assumes the SR8 demo seed; on a fresh simulator it taps
"Explore with sample data" so the app is in a populated state before
the first `snapshot(…)` call.

### Android — manual capture

See `store_metadata/play_console/screenshots_playbook.md` for the
step-by-step.  Summary: clean Pixel 8 Pro emulator → tap "Explore
with sample data" → walk the same 7 screens → frame through
Mockuphone → drop into `store_metadata/android/<locale>/images/phoneScreenshots/`.

## RevenueCat (subscriptions + lifetime IAP)

Same `--dart-define` pattern as Supabase. Set `REVENUECAT_IOS_KEY` and
`REVENUECAT_ANDROID_KEY` in your `env.json` (or pass them on the
command line). When unset, `SubscriptionService` silently stays in
Free tier — `tier` is always `SubscriptionTier.free`, so paid features
simply aren't accessible. The rest of the app runs normally.

### Tier model

The app supports three monetisation tiers, all driven by RevenueCat
entitlements:

| Tier | Entitlement | Product(s) | Notes |
|------|-------------|------------|-------|
| Free | (none) | — | Default state |
| Lifetime Local | `lifetime_local` | `lifetime_local` (non-consumable IAP) | One-time purchase, no cloud / community access |
| Pro Cloud | `pro_cloud` | `pro_cloud_monthly`, `pro_cloud_annual` | Subscription, full feature set |

A legacy entitlement named `pro` is grandfathered into Pro Cloud at
runtime (`SubscriptionService._resolveTier`) so customers who
purchased under the old single-tier model don't get downgraded when
the new pricing ships.

### Pre-release checklist

1. Create a RevenueCat account at <https://app.revenuecat.com>
2. Create apps for iOS and/or Android
3. **In the RevenueCat dashboard**, create TWO entitlements:
   - `pro_cloud` — attach `pro_cloud_monthly` + `pro_cloud_annual`
   - `lifetime_local` — attach the `lifetime_local` non-consumable IAP
4. **In App Store Connect / Google Play Console**, create three products
   with the IDs above. The Lifetime product type must be
   "non-consumable" (iOS) / "managed product, multi-quantity off"
   (Android) — NOT a subscription, otherwise users will be charged again.
5. **Pricing tiers**:
   - Pro Cloud Monthly — $4.99 (Tier 5)
   - Pro Cloud Annual — $29.99 (Tier 30)
   - Lifetime Local — $49.99 (Tier 50)
6. **Optional launch promo**: set `LifetimeLaunchPromo.launchDate` in
   `lib/config/subscription_tier_config.dart` to the UTC midnight of
   your launch day. The promo card shows the $39.99 badge for
   `promoDuration` days; the actual discount must be configured as an
   introductory offer in the App Store / Play Store dashboards
   (RevenueCat picks it up automatically).
7. Add the real RevenueCat keys to your CI secrets (`REVENUECAT_IOS_KEY`,
   `REVENUECAT_ANDROID_KEY`) and inject them into the build:

   ```sh
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=... \
     --dart-define=SUPABASE_ANON_KEY=... \
     --dart-define=REVENUECAT_IOS_KEY=appl_... \
     --dart-define=REVENUECAT_ANDROID_KEY=goog_...
   ```

8. Test a sandbox purchase for each of the three products before
   submitting to the store. After each purchase, verify in the app's
   Settings → Subscription section that the active tier label is
   correct ("Lifetime Local" vs "Kultivar Pro"). The Lifetime tier
   should NOT show a "Manage Subscription" row.

### Migrating existing `pro` customers

If you have customers who purchased under the old single-tier model:

- Keep the `pro` entitlement in the RevenueCat dashboard attached to
  the legacy monthly/annual products until those products are
  sunsetted. Existing customers retain their entitlement until they
  cancel.
- New purchases route to the new `pro_cloud` entitlement
  automatically because the new products are attached only to it.
- `SubscriptionService` treats `pro` as equivalent to `pro_cloud`, so
  legacy customers see Pro Cloud UI and behaviour with no action on
  their part.

## Launcher icons

App icons for every platform are generated from a single source PNG via
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons).
The config lives in `pubspec.yaml` and reads from `assets/branding/`.

### Regenerating after artwork changes

```sh
# After dropping new PNGs into assets/branding/:
dart run flutter_launcher_icons

# Then rebuild so installers pick up the new icon:
flutter clean
flutter build apk        # or appbundle / ipa / web / macos / windows
```

This rewrites:

- `android/app/src/main/res/mipmap-*/ic_launcher.png` (+ adaptive XML)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`
- `web/favicon.png` + `web/icons/Icon-{192,512}.png` + maskable PWA variants
- `windows/runner/resources/app_icon.ico`

Source artwork requirements live in `assets/branding/README.md`. The
generated files are checked into git so CI builds don't need to re-run
the generator — only re-run locally when the source artwork in
`assets/branding/` changes.

## Native launch screen

Replaces the white Flutter flash with the brand-dark Kultivar wordmark
on every native platform. Wired via
[`flutter_native_splash`](https://pub.dev/packages/flutter_native_splash);
config sits in `pubspec.yaml` under `flutter_native_splash:`.

### Regenerating after artwork or colour changes

```sh
# After editing the splash images or colour in pubspec.yaml:
dart run flutter_native_splash:create

# Then rebuild — installers replace the splash:
flutter clean
flutter build apk    # or appbundle / ipa / web
```

This writes:

- `android/app/src/main/res/drawable{,-night,-v21,-night-v21}/launch_background.xml`
- `android/app/src/main/res/values{,-night,-v31,-night-v31}/styles.xml`
- `android/app/src/main/res/drawable-*/{splash,background,android12splash,android12branding}.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` + `LaunchBackground.imageset/`
- `web/splash/img/*.png` + `web/index.html` + `web/splash/style.css`

### Design choices baked in

- **Dark in both light + dark OS modes.** Kultivar is dark-first; a
  white splash on a phone set to light mode would still flash jarringly
  before the dark Flutter UI takes over. We use `#0A0A0F` (same as
  `AppColors.bg`) on every platform, both light and dark.
- **Android 12+ vs legacy.** Android 12 replaced the legacy splash
  mechanism with a framework-level splash that only allows a small
  circular icon + an optional bottom branding image. We supply both:
  `splash_icon_android12.png` as the circular icon, `splash_image.png`
  as the branding image at the bottom.
- **iOS storyboard.** A single 1×1 `#0A0A0F` PNG (`background.png` in
  `LaunchBackground.imageset`) is scaled-to-fill across the screen,
  covering the default white storyboard background without us having
  to fork the storyboard XML.

## Telemetry consent

The user's stance on anonymous usage telemetry is owned by
`TelemetryConsentService` (`lib/services/telemetry_consent_service.dart`).
Three states, persisted in SharedPreferences under
`telemetry_consent_v1`:

| State | When | What fires |
|---|---|---|
| `notAsked` | Fresh install, before the first-launch consent sheet shows | Nothing — Sentry not initialised |
| `granted` | User tapped **Help improve** in the sheet or flipped the Settings toggle on | Sentry init on next app launch + every `ErrorReporter.report(...)` forwarded |
| `declined` | User tapped **No thanks** in the sheet (or dismissed it) or flipped the Settings toggle off | Nothing |

The first-launch sheet (`lib/widgets/telemetry_consent_sheet.dart`)
fires from `_ShellScreenState.initState` exactly once — when
`!hasBeenAsked`. Dismissing via barrier-tap or swipe counts as
**decline** (privacy-first default).

### Sentry gate

`bootstrapSentryAndRun(consentGranted: …)` checks BOTH
`isSentryConfigured` (build-time DSN) AND `consentGranted` (runtime
user choice). The SDK is **only** initialised when both are true —
guarantees zero network egress to Sentry until the user has
explicitly agreed.

Re-evaluation is on next app launch only: `SentryFlutter.init`
wraps `runApp` in `runZonedGuarded`, which can't be applied
retroactively. The Settings toggle's subtitle reflects this with
"Changes take effect on next app launch."

### Adding a new telemetry source

When wiring a future analytics SDK (Mixpanel, Amplitude, etc.):

1. Read `context.read<TelemetryConsentService>().hasGranted` before
   firing any event.
2. Initialise the SDK conditionally in `main.dart`, mirroring the
   Sentry pattern — DSN/key gate AND consent gate.
3. Add a `listen()` if you need to short-circuit live events when
   the user revokes mid-session (Sentry can't, but most event-based
   SDKs can).

## Sentry (crash reporting) — optional

Routed through the existing `ErrorReporter.setSink(...)` hook from Q3.
Pluggable via a single dart-define:

```sh
flutter run --dart-define=SENTRY_DSN=https://<key>@o0.ingest.sentry.io/<id>
```

- **Unset (default)**: `bootstrapSentryAndRun` in
  `lib/services/sentry_bootstrap.dart` is a no-op. The SDK is never
  initialised, no network egress, and every `ErrorReporter.report(...)`
  call still hits the debug-only print sink. This is the OSS / F-Droid /
  CI default.
- **Set**: `SentryFlutter.init(...)` runs before `runApp(...)`,
  wrapping the framework so unhandled errors are captured. The sink
  is swapped to forward every `ErrorRecord` to `Sentry.captureException`
  with `operation` as a tag and `extras` as scope extras.

### Pre-release checklist

1. Create a Sentry project at <https://sentry.io>.
2. Copy the DSN from **Settings → Projects → \<project\> → Client Keys**.
3. Add `SENTRY_DSN` as an encrypted CI secret.
4. Inject it via the build command:

   ```sh
   flutter build appbundle --release \
     --dart-define=SENTRY_DSN=https://... \
     --dart-define=SUPABASE_URL=... \
     # … other dart-defines …
   ```

5. Trigger a deliberate test error in a sandbox build and confirm
   it lands in the Sentry dashboard within ~30 s.

### Swapping to Firebase Crashlytics

The whole adapter lives in `lib/services/sentry_bootstrap.dart`. To
swap reporters, replace its body with the Crashlytics equivalent:

```dart
ErrorReporter.setSink((record) {
  FirebaseCrashlytics.instance.recordError(
    record.error,
    record.stackTrace,
    reason: record.operation,
    information: record.extras?.entries
        .map((e) => DiagnosticsProperty(e.key, e.value)) ?? const [],
  );
});
```

The rest of the codebase doesn't know which reporter is active.

## Why `--dart-define` and not just a config file?

Three reasons:

1. **No accidental commits** — there's no file with secrets sitting in
   the working tree waiting to be `git add .`'d.
2. **Environment separation** — dev / staging / prod builds can each
   inject their own values from CI secrets without code changes.
3. **Faster rotation** — when a key leaks you change it once in the
   Supabase dashboard and once in CI; no source-tree edit or rebuild
   pipeline.

Values are still embedded in the compiled binary, so anyone who
decompiles the app can extract them. That's expected for client-side
keys (Supabase anon key is designed to be public — it's protected by
Row-Level Security policies on the database side, NOT by being
secret).

## ⚠️ One-time action: rotate the previously committed key

If the URL or anon key was ever pushed to a shared branch (even if
gitignored later), treat it as compromised:

1. Log into the Supabase dashboard.
2. **Settings → API → JWT Settings → Rotate**.
3. Copy the new anon key into your `env.json` and CI secrets.
4. The old key is invalidated immediately.

Then double-check that Row-Level Security is enforced on every table:

```sql
-- For each public table, in Supabase SQL editor:
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;
-- Then add policies for what anon should be allowed to read/write.
```

Without RLS, the anon key is effectively a master key.
