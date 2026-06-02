// SR2 — Terms of Service
//
// Same packaging strategy as `privacy_policy.dart` — const string,
// compiled-in.  IMPORTANT: this is starter content drafted to fit
// Kultivar's actual feature set (local-first storage, optional
// community submission, paid tiers via App Store + Play Store).  It
// is NOT a substitute for legal review by a lawyer in your
// jurisdiction.  In particular, the cannabis-cultivation clauses,
// EU consumer-rights wording, and the liability / dispute sections
// MUST be reviewed for your target markets before launch.

const String kTermsOfServiceVersion = '2026-05-29';

const String kTermsOfServiceMarkdown = r'''
# Terms of Service

**Last updated:** 29 May 2026

Welcome to Kultivar. By installing or using the app, you agree to
these terms. They're written in plain English on purpose — please
take the time to read them.

---

## 1. Who can use Kultivar

Kultivar is a personal grow-tracking tool intended for adults legally
permitted to cultivate cannabis under the laws of the jurisdiction
where they live and use the app. You are responsible for ensuring
that your cultivation activity is lawful where you are.

**Kultivar is not legal advice.** Nothing in this app — the strain
library, the grow-day projections, the harvest analytics — should be
read as legal guidance on what you may or may not grow.

---

## 2. Your data, your responsibility

The bulk of your grow records, photos, notes, and harvest logs are
stored locally on your device. We do not have a copy.

- **Back up your data regularly.** *Settings → Backup → Export
  Backup* writes everything to an encrypted ZIP you can store wherever
  you like. We strongly recommend doing this before app updates and
  before changing devices.
- **Lost devices = lost data.** If your phone is lost, broken, or
  reset and you don't have a backup, we cannot recover your grow
  history. There is nowhere on our infrastructure where it exists.
- **Keep your backup passphrase safe.** Encrypted backups cannot be
  decrypted without it, and we cannot reset it.

---

## 3. Acceptable use

You agree not to:

- Reverse-engineer, decompile, or attempt to extract Kultivar's source
  code for the purpose of cloning or competing with it.
- Use the app to facilitate any cultivation activity that is unlawful
  where you are.
- Submit knowingly false data to the community benchmark feature in a
  way that pollutes the aggregate data.
- Use the app in any way that interferes with other users (for
  example, by abusing the community submission API at a volume that
  degrades the service).

We may, without notice, restrict access to the community-data feature
for users whose submissions appear designed to skew aggregate
statistics.

---

## 4. Subscription tiers

Kultivar offers three tiers:

- **Free** — 1 grow space, 3 active plants, 60 days of analytics
  history. The built-in strain library + comparison view is included.
- **Lifetime Local** — one-time purchase that removes the Free-tier
  caps permanently. No community / cloud features. Pay once, run
  forever on your device.
- **Pro Cloud** — monthly or annual subscription that adds community
  benchmarking and, in future releases, cross-device sync and cloud
  auto-backup.

### Billing

All transactions are processed by the **App Store (iOS)** or **Google
Play Store (Android)** — Kultivar does not bill you directly and does
not handle your payment details. Pricing displayed in the app reflects
the platform's localised store price at the moment of purchase.

### Subscription renewals

Pro Cloud subscriptions auto-renew at the end of each billing period
unless cancelled at least 24 hours before renewal. Manage or cancel:

- **iOS** — Settings → Apple ID → Subscriptions → Kultivar
- **Android** — Play Store → Profile → Payments & Subscriptions →
  Subscriptions → Kultivar

The in-app "Manage Subscription" link deep-links to the right page.

### Lifetime Local

Lifetime Local is a one-time, non-recurring purchase. Once it has been
purchased on your store account, it can be restored on any device
signed into the same Apple ID / Google account via *Settings →
Subscription → Restore Purchases*. No additional charges, ever.

### Refunds

Refunds for in-app purchases are handled by Apple / Google according
to their respective policies. We can't process refunds directly — you
need to request them through the store you bought from:

- **Apple** — [reportaproblem.apple.com](https://reportaproblem.apple.com)
- **Google** — Play Store → Account → Order history

---

## 5. Service availability

The local-only features work entirely offline and require nothing
from us. The community benchmark feature relies on our Supabase
backend, which we provide on a best-effort basis. We do not guarantee
uptime, and the feature may be temporarily unavailable for
maintenance.

If we ever decide to discontinue the community / cloud features, we
will give Pro Cloud subscribers at least 30 days' notice and offer
either a pro-rated refund or an automatic conversion to Lifetime
Local at no additional cost.

---

## 6. Updates

We push updates through the App Store and Play Store on a regular
cadence. Updates may add, remove, or change features. Some updates
are required for the app to keep functioning (for example, when a
platform OS update breaks an underlying API). We try to telegraph
material changes in the in-app changelog when applicable.

---

## 7. Disclaimers

Kultivar is provided "as is". The grow-day predictions, deficiency
identifier, environmental insights, and yield analytics are
**informational tools, not professional horticultural advice**. They
are derived from public information and the data you supply, and
should be treated as a second opinion rather than a definitive answer.

We make no warranty that:

- Predictions or recommendations will produce a successful harvest.
- The app will be free of bugs or interruptions.
- The community-data aggregate is statistically valid in any
  particular case (small sample sizes are surfaced as such, but
  use your own judgment).

---

## 8. Limitation of liability

To the maximum extent permitted by law, Kultivar's maintainers will
not be liable for any indirect, incidental, special, consequential,
or punitive damages, or any loss of profits, revenue, data, or use,
arising from your use of the app — including (without limitation)
crop loss, equipment damage, or legal exposure resulting from
cultivation activity.

Your sole remedy if you're unhappy with Kultivar is to stop using it.
Where applicable, our total liability for any claim related to the
app will not exceed the amount you have paid us for it (which, for
Free users, is zero).

This section does not exclude any liability that cannot be excluded
under applicable law (for example, certain consumer-protection rights
in the EU + UK).

---

## 9. Termination

You may stop using Kultivar at any time by uninstalling the app. We
may terminate your access to the optional community / cloud features
if you materially breach these terms (e.g. abuse of the community
submission API).

Termination of cloud features does not affect your locally-stored
grow data — that remains on your device and exportable via the
backup feature.

---

## 10. Governing law

These terms are governed by the laws of the jurisdiction where the
app maintainer is established (placeholder — replace with your
actual jurisdiction before App Store submission). Disputes will be
resolved in the courts of that jurisdiction, subject to any
mandatory consumer-protection rights you have where you live.

---

## 11. Changes to these terms

We may update these terms from time to time. The "Last updated" date
at the top will reflect the change. Material changes will be
surfaced in the app on first launch after the update. Continued use
of the app after the change constitutes acceptance of the new terms.

---

## 12. Contact

Questions about these terms? Reach Kultivar at:

**support@kultivar.io**

These terms are entered into with **Kultivar SA (Pty) Ltd**, registered
in the Republic of South Africa under the Companies Act, 2008
(Registration number 2026/429365/07). South African law governs the
agreement. Disputes that cannot be resolved by correspondence fall
within the jurisdiction of the South African courts.
''';
