# App Store Connect — App Privacy ("nutrition label") answers

Apple's App Privacy section (App Store Connect → My App → App
Privacy) is the equivalent of Google Play's Data Safety form. Both
must be answered before submission; both display publicly on the
store listing.

Per **App Store Connect: App Privacy Details** (App Review Guideline
5.1.2), the answers must match the actual data flows in the binary.
Mismatched declarations are grounds for rejection at re-review.

These answers are the source of truth for Kultivar 1.0. Update
whenever a new data type starts flowing (e.g. when sync ships).

---

## Are you collecting data?

**Yes (opt-in for everything sent off-device).**

The form then asks per-category. Kultivar's answers below.

## Per-category answers

### Contact info

- **Collected:** No
- *(Rationale: no account system, no name/email/phone capture.)*

### Health & Fitness

- **Collected:** No
- *(Rationale: although users record cannabis-effect ratings on
  harvests, we do not interpret these as health data, do not
  provide medical advice, and the disclaimer makes both clear.)*

### Financial info

- **Collected:** No
- *(Rationale: RevenueCat handles purchase validation; we never see
  the underlying receipt. The user's expense-tracker amounts stay
  on-device.)*

### Location

- **Collected:** Optional, precise (weather widget only)
- **Purpose:** App functionality
- **Linked to user:** No
- **Used for tracking:** No
- *(Rationale: the optional outdoor-weather card asks for the
  device's coarse location to fetch local forecast from
  Open-Meteo. The user can grant or deny; denying simply hides
  the card. Location is never persisted on our servers — we have
  no servers in that flow — and is never linked to any identifier.)*

### Sensitive info

- **Collected:** No
- *(Rationale: nothing fits Apple's "sensitive" definition.)*

### Contacts

- **Collected:** No

### User content (photos, audio, etc.)

- **Collected on-device only:** Yes
- **Sent off-device:** No
- *(Rationale: photos and voice notes stay in the device's app-
  documents directory only. They are NOT uploaded anywhere. The
  user can export them via the standard Share sheet but Kultivar
  does not.)*

For the form: declare **Photos or Videos = Not Collected** and
**Audio Data = Not Collected**, because Apple's definition of
"collected" is data that "leaves the user's device". Local-only
storage of user content does not require declaration.

### Browsing history

- **Collected:** No

### Search history

- **Collected:** No

### Identifiers

- **Collected:** No
- *(Rationale: no advertising IDs, no third-party IDs we read.
  RevenueCat assigns its own anonymous user ID for entitlement
  bookkeeping but it is internal to their SDK and not exposed to
  us; this matches Apple's documentation on the RevenueCat SDK
  privacy posture.)*

### Purchases

- **Collected:** No
- *(Rationale: as above — RevenueCat handles purchase validation
  through Apple's StoreKit; we never receive or store transaction
  records.)*

### Usage data (interactions, screens viewed)

- **Collected:** Yes, optional
- **Purpose:** App functionality, Analytics
- **Linked to user:** No
- **Used for tracking:** No
- *(Rationale: opt-in via the SR6 first-launch sheet. If the user
  grants consent, Sentry receives anonymised performance traces and
  screen-load metrics. No personally identifying data accompanies
  them.)*

### Diagnostics (crash data, performance data)

- **Collected:** Yes, optional
- **Purpose:** App functionality, Analytics
- **Linked to user:** No
- **Used for tracking:** No
- *(Rationale: same opt-in path as Usage data, same Sentry
  destination. Crash stack traces are anonymous — no symbol names
  contain personal data.)*

### Other data types

- **Collected:** Yes, optional — aggregate harvest yield benchmarks
- **Purpose:** App functionality
- **Linked to user:** No
- **Used for tracking:** No
- *(Rationale: opt-in via Settings → Community → Share anonymous
  grow data, gated by Pro Cloud tier. Submits the strain name
  (normalised), dry weight in grams, grow-day counts, and a few
  optional attributes to Supabase. No personally identifying data
  in the payload.)*

## Tracking

**Tracking** in Apple's privacy lexicon means linking data about a
user from your app to data about that user from other companies' apps,
websites, or offline activity — typically for ads or measurement
across apps.

- **Kultivar does any tracking?** **No.**
- *(Rationale: we don't link any data to a user identifier we'd
  combine with third-party data. The Sentry / Supabase /
  RevenueCat flows are first-party only, and none use shared
  identifiers like the IDFA / IDFV / device fingerprint.)*

This means Kultivar does NOT need to display the App Tracking
Transparency prompt. Confirmed by checking that `NSUserTrackingUsage
Description` is absent from `Info.plist`.

---

## Cross-reference with the GitHub-hosted Privacy Policy

The policy at `docs/privacy.html` (generated from
`lib/legal/privacy_policy.dart`) is the long-form version of these
answers. The two must stay aligned — if you change a data flow,
update both:

1. The Dart const (in-app rendering)
2. Regenerate the HTML (`python tools/generate_legal_html.py`)
3. Re-answer the affected category in App Store Connect's App Privacy
   section AND Google Play's Data Safety section
