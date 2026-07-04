# Changelog

All notable changes to **Kultivar** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

See `BUILD.md` for the release process, version-bump rules, and git tag scheme.

## [Unreleased]

### Performance
- **Cold start no longer blocks on RevenueCat's network fetch (~15 s
  splash hang fixed).**  `main()` awaited `SubscriptionService.init()`,
  which chained `Purchases.getCustomerInfo()` + `Purchases.getOfferings()`
  — two network round-trips through Google Play Billing — before the
  first frame could paint.  With Billing slow (or the Play products not
  yet configured), boot stalled 10-15 s on the splash.  init() now only
  awaits the local `Purchases.configure()` (which already surfaces the
  on-device entitlement cache); the fresh fetch runs unawaited in the
  background and notifies when the tier resolves.  Until then the user
  is treated as Free — the same state every feature gate already
  handles.  Also moved the Android 13+ POST_NOTIFICATIONS permission
  request out of `main()` into a post-first-frame callback: on a fresh
  install the system dialog used to render over the splash and block
  time-to-first-frame until answered.

### Changed
- **Settings screen decluttered with collapsible groups.** A new
  reusable `_CollapsibleGroup` widget folds long clusters of rows behind
  a single tappable header (animated expand, rotating chevron, proper
  expanded/collapsed screen-reader semantics). Applied to four sections:
  Notifications now folds its eight care-reminder toggles behind a
  "Care reminders" row carrying a live "N/8 on" pill, and tucks the
  battery + delivery-test tiles into "Troubleshooting"; Data export folds
  the five per-type exports behind "Export by type"; Backup folds cloud
  share / encryption / details behind "More backup options"; the App
  section folds storage cleanup + replay-intro behind "Maintenance"
  while keeping the destructive "Clear all data" visible. Five new
  localized group labels added across all 9 locales (Afrikaans + isiZulu
  join the existing pending native-speaker review).

## [1.0.0] — 2026-06-30

Initial public release.

### Fixed
- **Adaptive launcher icon — Android 13+ themed icons + round-icon
  launchers.**  Three gaps closed:
  (1) `<monochrome>` layer added to `mipmap-anydpi-v26/ic_launcher.xml`
  so Material You themed icons recolour correctly instead of falling
  back to the default;
  (2) new `ic_launcher_round.xml` so Samsung One UI / Pixel
  round-shape launchers get the same adaptive treatment;
  (3) `android:roundIcon` wired into AndroidManifest.xml, with legacy
  raster fallbacks copied across all 5 density buckets so pre-API-26
  devices still resolve cleanly.  `flutter_launcher_icons` 0.13.x
  doesn't emit the monochrome layer reliably even when configured —
  fix documented inline.

### Tooling
- **`tools/release.ps1` — automated release pipeline.**  Eight stages:
  clean-tree check → preflight gate → version bump (interactive or
  `-Version 1.0.1`) → CHANGELOG roll → commit → AAB build →
  git tag → upload checklist.  `-DryRun` shows the plan without
  mutating anything.  Pairs with `preflight.ps1`.

### Added
- **Public landing page at `docs/index.html`** — dark-themed, mobile-
  first, zero external dependencies (no fonts, no JS frameworks, no
  analytics).  Hero with phone-mockup placeholder, three pillars
  (privacy / polish / 9 languages), 9-feature grid, 3-tier pricing
  teaser, SA call-out, footer with `<COMPANY_REG_PLACEHOLDER>` slot
  for CIPC reg number, social handle slots commented in for later.
  Deploys instantly via GitHub Pages from `/docs` — live at
  `kultivar.io` once DNS propagates.
- **`<COMPANY_REG_PLACEHOLDER>` in legal docs** (privacy + terms) so
  the SA company registration number can be slotted in once CIPC
  issues it.  Contact addresses updated to `support@kultivar.io`.
- Pre-flight script now scans `lib/legal/` and `docs/` for
  placeholder markers in addition to `store_metadata/`.
- `tools/generate_legal_html.py` no longer overwrites
  `docs/index.html`; the legal index moved to `docs/legal.html` so
  the marketing landing survives regenerations.

- **In-app review prompt** (`lib/services/review_prompt_service.dart`).
  Fires the native App Store / Play Store review UI after the user
  shares a Grow Report PDF — the highest-satisfaction moment in the
  app.  Five-guard policy: not in demo mode, has at least one
  completed harvest, first launch ≥ 7 days ago, no prompt in the
  last 90 days, has not opted out.  A Settings tile ("Rate Kultivar")
  exposes a manual entry that bypasses every cooldown.  8 new tests
  cover the policy.  Uses the `in_app_review` package.

### Tooling
- **Pre-flight check script** (`tools/preflight.ps1`).  One command
  runs six release-gate checks in order: `flutter analyze`,
  `flutter test`, ARB key parity across all 9 locales, placeholder
  hunt in `store_metadata/`, CHANGELOG `[Unreleased]` sanity, and
  pubspec version vs. latest git tag.  Exit code = number of failed
  gates so it slots straight into CI.  ASCII-only output for
  PowerShell 5.1 compatibility.

### Tests
- **Boot-the-app smoke widget test** (`test/screens/home_smoke_test.dart`).
  Pumps the home screen behind the same MultiProvider shell production
  uses, seeds the repo with a shape matching `DemoDataService.seed`,
  and asserts the grid renders the expected plant + space cards.
  Pairs with a sibling "empty repo doesn't crash" test for the
  fresh-install path.  Catches first-run-flow regressions cheaply
  (sub-second per test, no platform-channel dependencies).
  Adds `HiveService.initForTests` / `resetForTests` (`@visibleForTesting`)
  so screens reading `repo.environmentLogs` can pump under the test
  binding without dragging in the path-provider channel mock.

### Polish
- **P2.5 — Single source of truth for the terpene colour palette.**
  The 10-entry myrcene / caryophyllene / limonene / linalool / pinene /
  terpinolene / ocimene / humulene / bisabolol / valencene map was
  duplicated across `strain_library_screen.dart`,
  `strain_detail_screen.dart`, and `widgets/strain_preview_sheet.dart`.
  Extracted to `lib/theme/terpene_colors.dart`; three copies → one
  import.
- **P2.6 — `AppOpacity` constants** (`lib/theme/app_opacity.dart`).
  Replaces scattered raw alpha literals (0.08 / 0.12 / 0.25 / 0.30 /
  0.40 / 0.50 / 0.70 / 0.80 …) with named tokens organised by intent:
  `tint*`, `border*`, `scrim*`, `text*`.  Theme chrome (theme, sheet,
  toast) migrated; feature widgets are migrated opportunistically as
  they're touched.
- **P3.8 — `AppSpacing.borderHair` / `borderEmphasis`.**  Documents the
  two canonical border widths (1 px structural / 1.5 px semantic
  emphasis).  Token-only — no bulk migration; the existing 1.5 px
  borders are correct and intentional.
- **P3.9 — `AppSpacing.fabClearance` token.**  Replaces the raw `96`
  bottom-padding magic that three expense-tracker scrollables used to
  clear the FAB.

### Performance
- **P1.5 — Explicit `PaintingBinding.imageCache` limits** (200 MB /
  2000 entries) matched to Kultivar's post-P1.4 thumbnail workload.
  Default Flutter caps (100 MB / 1000) would have evicted hot tiles
  on long photo-timeline scrolls; doubling the budget keeps a typical
  user's full active-plant photo set warm without crowding other
  caches under memory pressure.
- **P1.4 — `cacheWidth` / `cacheHeight` on every `Image.file` thumbnail.**
  Native iPhone photos decode at 4032 × 3024 ≈ 48 MB each.  A populated
  30-photo timeline grid was peaking at ~1.4 GB of bitmap memory and
  would OOM-crash on iPhone SE / iPad mini.  New helper
  `lib/utils/image_cache_size.dart` centralises the decode-cap policy
  (logical px × devicePixelRatio).  Applied to every thumbnail call
  site: home plant cards (32 px), plant detail strips (60 / 72 px),
  plant timeline rows (140 px), photo timeline grid tiles
  (`cacheHeight: tileHeight`), report-screen grid (160 px), attachment
  picker (90 px).  Full-screen viewers / pinch-zoom InteractiveViewers
  / the shareable Grow Card backdrop intentionally stay uncapped — they
  need native resolution.  Memory reduction on the photo timeline:
  ~150× per tile.
- **P1.3 — `precacheImage` neighbours in the slideshow viewer.**  The
  flipbook PageView.builder now warms the ±1 photo in `ImageCache` on
  every page change so swipe + auto-advance show no black frame.
- **P1.2 — `ListView.builder` in the expense tracker.**  The two
  aggregate tabs (by-category, by-plant) were instantiating every row
  eagerly.  Switched to `.builder` so off-screen rows defer their
  per-plant cost-per-gram computation.
- **P1.1 — TabController setState guard in Strain Library.**  The
  listener was rebuilding ~150 strain cards on every animation tick
  of the tab swipe — 60-120 rebuilds per swipe.  Now guards on
  `indexIsChanging` so only the landing index triggers a rebuild.

### Added
- **SR9 — Fastlane snapshot configuration** for automated iOS
  screenshot capture.  `ios/fastlane/{Fastfile,Snapfile}` plus an
  `ios/RunnerUITests/RunnerUITests.swift` XCUITest driver walk the
  app through Home → Plant Detail → Notes → Analytics → Archive →
  Grow Report → Paywall and emit PNGs for 3 device classes × 9
  locales.  Captured PNGs are git-ignored; lanes
  `screenshots` / `upload_screenshots` / `screenshots_and_upload`
  cover capture + push to App Store Connect.  Android stays manual
  but is documented end-to-end in
  `store_metadata/play_console/screenshots_playbook.md` (Pixel 8
  Pro emulator + Mockuphone framing, ~6 min per locale).
- **SR8 — DemoDataService accuracy review.**  Closed four gaps so
  the App Store reviewer sees a populated app on the first tap of
  "Explore with sample data": dry-room note now uses °C
  (was °F, inconsistent with the rest of the app); completed runs
  carry `smell` / `effect` / `bagAppeal` sub-scores so the Grow
  Report panel renders; completed plants set `flipDate`,
  `harvestedDate`, `wetWeight`, `dryWeight`, `archiveReason` so the
  timeline shows the "Flipped to Flower" event; ~6 expenses per
  completed plant + 3 space-level expenses seed the Costs tab so
  it's no longer empty.
- **SR7 — Pre-drafted store review answers.** App Store Connect
  review notes (`store_metadata/ios/<locale>/review_information/
  notes.txt`) for en-US + af-ZA + zu-ZA. App Privacy nutrition
  label answers (`store_metadata/ios/app_privacy_answers.md`).
  Google Play App Content + Data Safety + Restricted-Content
  cannabis declaration (`store_metadata/play_console/
  app_content_declarations.md`). All answers pre-justified against
  the actual data flows in the binary so submission day is
  paste-and-go, not research-and-draft.
- **SR3 — Hosted Privacy Policy + Terms of Service pages**
  (`/docs/{index,privacy,terms}.html`). Generated by
  `tools/generate_legal_html.py` from the same markdown constants
  the in-app viewer uses — single source of truth, one command to
  regenerate. GitHub Pages serves them from `/docs` so the App
  Store + Play Store store-listing URL requirement is satisfied.
  Pages carry zero external dependencies (no CDN fonts, no
  JavaScript, no tracking) — the right posture for a legal page.
- **South Africa expansion** — Afrikaans (`af`) and isiZulu (`zu`)
  added to the language picker.  Both are baseline translations
  derived from the Dutch source (Afrikaans) and a careful first
  pass against the English source (isiZulu).  **Both require
  native-speaker review before public launch** — see the
  `@@x-review-note` block at the top of each `.arb` file.
- **Play store metadata for `af-ZA` and `zu-ZA`** — title /
  short description / long description / changelog files under
  `store_metadata/android/` ready for Fastlane `supply`.
  Long descriptions explicitly cite the Cannabis for Private
  Purposes Act 7 of 2024 + jurisdictional disclaimer.
- **Auto-default currency from OS locale** — fresh installs now
  pick a sensible currency for the user's country instead of
  hard-coding £.  ZA users land on Rand (R), US on USD, the 20
  eurozone members on €, etc.  Once chosen the symbol is persisted
  so later device-region changes don't silently flip the picker.
- **Africa/Johannesburg timezone smoke test** — 5 new tests pin
  SAST behaviour (fixed UTC+2, no DST, day-boundary math, instant
  preservation across `TZDateTime.from`).  Serves as a regression
  net for the UP4 `timezone` 0.9 → 0.11 upgrade.
- A10 — half-star rating control (`HalfStarRow`) now exposes
  slider semantics with `value`, `onIncrease`, `onDecrease` so
  screen-reader and switch-control users can adjust ratings even
  though the visual half-star tap zones are below the 44 pt
  WCAG 2.5.5 target.

### Fixed
- Voice-note delete button restored to a 44 pt hit target — the
  prior `constraints: const BoxConstraints()` shrank the touch
  area to roughly 20 px which failed WCAG 2.5.5.  Visual icon
  size unchanged.

### Accessibility
- TalkBack/VoiceOver-aware labels on every meaningful photo
  (`Image.file`) — plant detail thumbnails, photo timeline grid,
  full-screen viewer, grow report grid all announce category + date
  instead of a bare "image" node.
- Bottom navigation tabs now expose explicit `button: true` +
  `selected: …` semantics — screen readers announce "Home tab,
  selected" instead of just reading the label.
- Decorative-only surfaces excluded from semantics (Home AppBar
  logo, line-art empty-state illustrations, plant-tile thumbnails
  inside cards whose labels already cover them) so TalkBack doesn't
  inject redundant "image" nodes before announcing the real content.

### Added
- **Lifecycle tracking** — plants step through Growing → Harvested → Drying
  → Curing → Completed, with stage-aware reminder presets.
- **Multi-space support** — independent grow tents / rooms with their own
  environment logs, care schedules, and capacity tracking.
- **Per-plant notes** with categories (observation, issue, milestone,
  watering, feeding, IPM, training, measurement, transplant), voice
  attachments, photo timeline, and free-form tags.
- **Strain library** — built-in catalog with effective flowering days,
  landrace filter, full strain comparisons; user-added custom strains.
- **Environment monitoring** — temperature, humidity, VPD calculator,
  per-space optima with out-of-range and stale-data alerts.
- **Harvest workflow** — wet weight (optional), dry weight, harvest-log
  quality assessment (overall + smell + effect + bag-appeal sub-scores),
  burping reminders during cure.
- **Grow reports** — generated PDF per completed cycle covering duration,
  yields, environment summary, training notes, recommendations.
- **Expense tracker** — log per-plant and per-space costs, cost-per-gram
  analytics, attribution edit + reassign, 22-currency picker.
- **Analytics dashboard** — dry-weight trend with theme-aware contrast,
  cross-grow comparison, strain leaderboard, training stress impact.
- **Subscription model** — Free (1 space, 3 plants, 60-day analytics
  window, full strain library + comparisons), Lifetime Local (one-time
  unlock for every local feature; no cloud), Pro Cloud (subscription
  unlocking community percentile benchmarking + future sync).
- **Privacy-first defaults** — Sentry crash reporting only initialises
  when a build-time DSN is supplied AND the user opts in; community
  benchmark service short-circuits to null when access isn't granted.
- **i18n** for English, German, Spanish, French, Italian, Dutch,
  Portuguese — including settings strings, common dialogs, and
  archive / notes surfaces.

### Security
- Backup encryption via AES-256-GCM + PBKDF2-HMAC-SHA256 with versioned
  KVTB envelope (200k iterations, random salt + nonce per call,
  MAC-verified on decrypt — tampering, wrong-passphrase and
  truncated-envelope cases all throw before producing partial output).
- App Lock with biometrics (Face ID / Touch ID / Android BiometricPrompt)
  + PIN fallback.

[Unreleased]: https://github.com/KultivarSA/kultivar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/KultivarSA/kultivar/releases/tag/v1.0.0
