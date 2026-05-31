# Kultivar

**The grow-cycle journal that respects your privacy.**

A polished, offline-first cannabis grow tracker for adult home growers
in jurisdictions where cultivation is legal. Every photo, every note,
every harvest stays on your device. No account required. No cloud
sync forced on you. No data sold to anyone, ever.

Built for serious hobbyists who care as much about how the app looks
and feels as they do about the data it captures.

---

## What it does

- **Track every cycle from seed to cure.** Multi-space organisation
  (veg tent / flower room / dry room), per-plant photo timelines,
  stage-aware reminders, harvest logs with smell / effect / bag-appeal
  sub-ratings.
- **Know what each gram cost you.** Per-plant expense tracking
  (seeds, nutrients, IPM, substrate, water, electricity) → automatic
  cost-per-gram on every completed run.
- **Compare runs side-by-side.** Cross-grow analytics, yield-per-strain
  charts, stage-duration drift, environment overlays.
- **Generate a shareable Grow Report.** Every completed cycle becomes
  a one-page PDF you can share with your community or keep as a
  personal archive.
- **Built-in strain library.** ~150 strains with flowering time,
  terpene profile, expected yield, training recommendations. Add your
  own or extend an existing entry.
- **Environment monitoring.** Log temp / humidity / VPD per space;
  charts that highlight drift outside your target window.
- **Voice notes, free-form tags, photo annotations.** Capture what
  your hands can't type.

---

## Why it's different

### Privacy-first by default

Most grow trackers ship as cloud-first. Kultivar is the opposite.
Your data lives in local storage (SharedPreferences + Hive). A
brand-new install needs no account, no email, no cloud signup —
just open it and start tracking.

There's an optional Pro Cloud tier for users who want sync /
community benchmarks, but it's strictly opt-in and the core
journaling experience never asks for it.

### Built to be polished, not just functional

Where most grow apps look like generic Android list views,
Kultivar ships with:

- A custom dark-mode design system with documented colour tokens,
  spacing tokens, opacity tokens, typography tokens
- 9 fully-localised UI languages (English, German, Spanish, French,
  Italian, Dutch, Portuguese, **Afrikaans, isiZulu**)
- Skeleton loading placeholders, line-art empty states, half-star
  rating controls with full accessibility semantics
- Tap-target sizes audited against Apple HIG (44 pt) and Material 3 (48 dp)
- Currency auto-detection from OS locale (47 countries — ZAR for
  South Africa, EUR for the eurozone, GBP for UK, etc.)

### Three-tier pricing, no dark patterns

- **Free** — track unlimited plants and harvests, full strain library,
  cost tracking, photo timeline, environment logging. The complete
  hobbyist experience.
- **Lifetime Local** (one-time IAP) — analytics history, strain
  comparison, cross-grow comparison, home-screen widget, unlimited
  exports.
- **Pro Cloud** (subscription) — everything above plus community
  yield benchmarks and (planned) cross-device sync.

Free is not a teaser. You can complete a full grow cycle, generate a
PDF report, and never see a paywall.

---

## Available on

- iOS App Store — *coming soon*
- Google Play Store — *coming soon*

Initial launch markets: 🇿🇦 South Africa, 🇺🇸 USA, 🇩🇪 Germany, 🇪🇸 Spain,
🇫🇷 France, 🇮🇹 Italy, 🇳🇱 Netherlands, 🇵🇹 Portugal — pending platform
review.

---

## Built with

Flutter (Dart) — single codebase, native performance on iOS and
Android. The project deliberately stays lean:

- `provider` for state, no over-engineered redux/bloc abstraction
- `hive` for fast local persistence
- `fl_chart` for the analytics surfaces
- `flutter_local_notifications` for stage-aware reminders
- `revenue_cat` for cross-platform subscription handling
- `sentry` for opt-in crash reporting (gated by explicit telemetry consent)
- `supabase` for the optional community benchmark backend

297 tests covering the repository, services, workflows, widget
smoke paths, and the cryptographic backup envelope. CI runs
`flutter analyze` + `flutter test` on every PR.

---

## Legal

- 📄 [Privacy Policy](https://marcokulik.github.io/canna_grow/privacy.html)
- 📄 [Terms of Service](https://marcokulik.github.io/canna_grow/terms.html)

Both pages are hosted from this repo's `/docs` folder via GitHub Pages.
They're generated from the same markdown the in-app viewer uses, so
the two never drift apart.

### Legal note on cannabis

Kultivar is a **tracking tool**. It does not sell cannabis, facilitate
transactions, deliver products, or in any way enable purchasing. It's
intended for adult users in jurisdictions where personal cultivation
is legal — including (but not limited to) Cannabis for Private
Purposes Act 7 of 2024 (South Africa), adult-use programmes in
several US states, Germany's Cannabis Act, and similar frameworks in
Canada, Spain (cannabis social clubs), and the Netherlands.

Users are responsible for ensuring their cultivation activities are
legal in their jurisdiction. Kultivar is not legal advice.

---

## For developers

The full build / signing / release workflow lives in
[`BUILD.md`](BUILD.md). Highlights:

```powershell
# Run locally
flutter pub get
flutter run

# Pre-flight check before release (analyze + test + ARB parity +
# placeholder hunt + CHANGELOG sanity + version bump check)
pwsh ./tools/preflight.ps1
```

Changelog: [`CHANGELOG.md`](CHANGELOG.md).

This repository's public surface is read-mostly. Pull requests for
typo fixes / accessibility improvements / translation polish are
welcome; larger feature work happens internally and is upstreamed in
batches.

---

## License

Source is published as a reference and for transparency. Not licensed
for commercial redistribution.
