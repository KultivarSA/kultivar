# Kultivar — Roadmap

Living document. The v1.0 launch is "ship the product." Everything
below is "compound on the launch signal."

> **Audience note.** This roadmap is public for the same reason
> `LAUNCH.md` is public — transparency reinforces the privacy-first
> brand. It also doubles as a recruitment / contributor signal.

---

## v1.1 — the headline + the polish

**Release window:** ~10 weeks after v1.0 public launch (one v1.0.x
release every 1-2 weeks during the build, then v1.1.0 as the
coordinated marketing push).

**Three features, ranked by impact:**

1. 🌐 **Cross-device sync (Pro Cloud)** — the headline. Justifies the
   Pro Cloud subscription tier. End-to-end encrypted.
2. 🌞 **Outdoor mode** — SA-specific differentiator. Weather-aware
   reminders. Photoperiod tracking.
3. 📈 **Yield prediction** — small dev cost, viral marketing potential.

What's **deliberately deferred** to v1.2: plant ID AI, community feed,
iOS launch (parallel track in LAUNCH.md month 2-3, not a v1.x feature).

---

# 🌐 Cross-device sync — technical spec

## Why this is the headline

Pro Cloud's R59/month price tag needs a "must-have" feature. Community
benchmarks alone don't convert. Cross-device sync does, because:

1. Every grow-app user who owns more than one device asks for it
2. **Privacy-first sync is genuinely rare** — most cloud-sync apps
   read your data. We won't.
3. Existing Supabase infrastructure makes this a backend-light project
4. The `BackupCrypto` AES-256-GCM envelope we already shipped (Q-tasks)
   gives us the encryption primitives for free

## Architecture overview

```
┌───────────────┐                        ┌───────────────┐
│   Phone       │                        │   Tablet      │
│   (local)     │                        │   (local)     │
│               │                        │               │
│ SharedPrefs   │      ┌──────────┐      │ SharedPrefs   │
│ Hive          │ ◄──► │ Supabase │ ◄──► │ Hive          │
│ Photos        │      │          │      │ Photos        │
│               │      │ Postgres │      │               │
│ SyncEngine    │      │ Storage  │      │ SyncEngine    │
│   • pull      │      └──────────┘      │   • pull      │
│   • reconcile │                        │   • reconcile │
│   • push      │                        │   • push      │
└───────────────┘                        └───────────────┘

  ALL data encrypted client-side with user passphrase.
  Supabase stores ciphertext only.  Even Kultivar can't read it.
```

## Data model

### Generic sync envelope (one row per entity)

Every syncable entity follows the same Postgres schema:

```sql
CREATE TABLE sync_envelopes (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id),
    entity_type TEXT NOT NULL,    -- 'plant', 'note', 'expense', etc.
    entity_id   UUID NOT NULL,    -- the entity's own UUID
    version     BIGINT NOT NULL,  -- monotonic per (user, entity_id)
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    device_id   TEXT NOT NULL,    -- the device that wrote this row
    payload     BYTEA NOT NULL,   -- AES-256-GCM ciphertext
    is_tombstone BOOLEAN DEFAULT false,

    UNIQUE (user_id, entity_id, version)
);

CREATE INDEX sync_envelopes_user_updated_idx
    ON sync_envelopes (user_id, updated_at DESC);
```

### Why one table per envelope vs. one table per entity type

**Pro:** Schema-less server — adding new entity types in the client
doesn't need a migration server-side.

**Pro:** Pull queries are uniform: "give me all envelopes since `cursor`".

**Pro:** Tombstones work identically for every entity type.

**Con:** Loses Postgres-side queryability (can't `SELECT * FROM plants
WHERE strain = 'Blue Dream'`). Acceptable because data is encrypted —
server can't query it anyway.

### Row-Level Security

```sql
ALTER TABLE sync_envelopes ENABLE ROW LEVEL SECURITY;

CREATE POLICY sync_envelopes_self ON sync_envelopes
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
```

Even with a stolen API key, an attacker can't read another user's
envelopes. Defence in depth on top of E2EE.

### Photos via Supabase Storage

```
storage://photos/<user_id>/<photo_uuid>.enc
```

Each photo encrypted client-side with the same passphrase-derived key.
File extension `.enc` signals the storage rules: "this is opaque
ciphertext, never serve through any CDN that does image processing."

Storage RLS mirrors the table policy:
```sql
CREATE POLICY photos_self ON storage.objects
    FOR ALL
    USING (bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text);
```

## Encryption

### Key derivation

User picks a passphrase the first time they enable Pro Cloud sync:

```
master_key = Argon2id(
    passphrase,
    salt = user_id || 'kultivar.sync.v1',
    iterations = 3,
    memory = 64 MiB,
    parallelism = 4,
) → 32 bytes
```

Argon2id parameters chosen to take ~500ms on a 2020 mid-range Android
phone — slow enough to make passphrase brute-force expensive, fast
enough not to block UI.

### Per-envelope encryption

```
nonce = random 12 bytes
ciphertext, tag = AES-256-GCM(
    key = master_key,
    plaintext = JSON(entity),
    nonce = nonce,
    additional_data = entity_type || entity_id || version,
)
payload = nonce || ciphertext || tag
```

**Additional Authenticated Data (AAD)** prevents an attacker from
swapping `entity_type` or replaying old `version` numbers.

### Key storage on device

| Platform | Where |
|---|---|
| Android | Android Keystore (hardware-backed when available) |
| iOS | Keychain Services with `kSecAttrAccessibleAfterFirstUnlock` |

The passphrase is **never stored**. The derived `master_key` lives
only in process memory + the platform secure enclave.

### Forgotten passphrase

If the user forgets it: **their cloud data is lost forever**. This
is the trade-off for true E2EE. We mitigate with:

1. On enable: force the user to write down or screenshot the
   passphrase (with a "I have saved this" confirmation gate)
2. On every login: prompt to add a backup recovery method
   (post-v1.1: email-based recovery using a separate key envelope)
3. Local data is always recoverable — even if cloud sync is lost,
   the phone has the unencrypted copy

This is the same trust model as Signal, Bitwarden, ProtonMail. Marketing
position: **"We can't read your grow journal because we built it that
way. Not even with a court order."**

## Sync protocol

### State machine

```
       ┌─────────┐
       │  Idle   │ ◄──────────┐
       └────┬────┘            │
            │                 │
            ▼                 │
       ┌─────────┐            │
       │ Pulling │            │
       └────┬────┘            │
            │                 │
            ▼                 │
       ┌─────────────┐        │
       │ Reconciling │        │
       └──────┬──────┘        │
              │               │
              ▼               │
         ┌─────────┐          │
         │ Pushing │          │
         └────┬────┘          │
              │               │
              ▼               │
         ┌────────┐           │
         │  Done  │ ──────────┘
         └────────┘

   On error: → Error → (retry with exponential backoff) → Pulling
   Max 3 retries; on 4th, surface to user with manual retry.
```

### Trigger points

| Event | Action |
|---|---|
| App moves to foreground | Sync now |
| App is in foreground + 10 min elapsed | Sync now |
| User taps "Sync now" in Settings | Sync now |
| User mutates data | Push only (no pull) |
| Network reconnects after offline | Sync now |
| App background (iOS Background Fetch / Android WorkManager) | Sync if last sync > 1 hour ago |

### Pull

```
GET /rest/v1/sync_envelopes
    ?user_id=eq.{uid}
    &updated_at=gte.{cursor}
    &order=updated_at.asc
    &limit=500
```

`cursor` = local SharedPreferences `last_sync_cursor` (defaults to epoch).

Pagination by `limit=500`; if response has 500 rows, loop with
`updated_at=gte.{last_row_updated_at}`.

After pull: for each envelope, decrypt → reconcile → apply to local
state → update `last_sync_cursor`.

### Push

```
POST /rest/v1/sync_envelopes
[
  {
    "id": "<new uuid>",
    "user_id": "{uid}",
    "entity_type": "plant",
    "entity_id": "<plant uuid>",
    "version": <local.version + 1>,
    "device_id": "{this_device}",
    "payload": "<base64 ciphertext>",
    "is_tombstone": false
  },
  ...
]
```

`SyncQueue` (local service) tracks pending push items.  Push batches
up to 100 envelopes per request.  Successful push removes items from
the queue.

## Conflict resolution

Conflicts only arise when the same `entity_id` has been mutated on
two devices since the last sync.

### Strategy: per-field LWW + tombstones

For each conflicting entity:

1. Decrypt both versions
2. For each field in the entity:
   * If `field` exists in both:
     * Compare `field.updated_at` (each field has a sub-timestamp)
     * Latest wins
   * If `field` exists in one but not the other:
     * If newer side has a tombstone → keep tombstone (deletion wins)
     * Otherwise → keep present field
3. For collection fields (`photo_ids[]`, `tags[]`):
   * Compute set-union of both sides
   * Remove anything in the tombstone set
4. The reconciled entity's `version` = `max(local, remote) + 1`
5. Push the reconciled version on the next push cycle

### When user intervention is required

Two cases:

1. **Entity deleted on one device, edited on the other**
   * Prompt: "You deleted *Blue Dream #3* on your tablet but edited
     it on your phone. Keep the edit? / Confirm deletion?"
2. **Major numerical disagreement** (wet weight differs by > 50g, etc.)
   * Prompt: "*Blue Dream #3* wet weight is 287g on phone, 145g on
     tablet. Which is correct?"

Conflicts are surfaced via a **conflict inbox** in Settings — never
block normal app usage. User resolves at their own pace.

## Migration story

Users on Lifetime Local who upgrade to Pro Cloud will already have
local data. First sync:

1. User enters passphrase (twice for confirmation)
2. Local data → encrypted → uploaded as initial envelopes
3. `SyncEngine` reports "Initial backup complete — your data now syncs"

Users on a fresh second device:

1. Install Kultivar from Play Store
2. Sign in with Pro Cloud account
3. Enter the same passphrase
4. App pulls all envelopes → decrypts → populates local state
5. From here, both devices stay in sync

Users who change their passphrase:

1. Settings → Sync → Change passphrase
2. New `master_key` derived
3. All cloud envelopes re-uploaded with the new key
4. Old envelopes deleted server-side after confirmation

## Telemetry / observability

What we report (with telemetry consent):

* Sync success/failure count per day
* Average sync duration
* Conflict count per day
* Most-frequent conflict entity type

What we never report:

* Anything from the decrypted payloads
* Counts of plants, notes, expenses (user-private)
* Device identifier (only hashed device ID)

---

# 🌞 Outdoor mode — technical spec

## What's different from indoor

| Aspect | Indoor | Outdoor |
|---|---|---|
| Light schedule | Manual: 18/6 veg, 12/12 flower | Driven by latitude + season |
| Watering | Timer-based | Weather-aware: skip on rain forecast |
| Temperature target | User-set | Compared against weather data |
| Photoperiod tracking | Stage transitions are user-triggered | Vegetative → flowering driven by daylight hours (< 13.5h) |
| Risk events | Equipment failure (power cut, fan stop) | Frost, hail, extreme heat |
| Analytics | "Watts per gram" | "Sunlight hours per gram" |

## Data model changes

### Add to `GrowSpace`

```dart
enum GrowMode { indoor, outdoor, greenhouse }

class GrowSpace {
  // ...existing fields...
  GrowMode growMode;
  double? latitude;
  double? longitude;
  bool useNaturalPhotoperiod;
  // ...
}
```

Latitude/longitude collected on space creation if `growMode != indoor`.
Used for sunrise/sunset times + weather API queries.

### Add to `Reminder`

```dart
enum WeatherAwareness {
  none,
  skipIfRainForecast,
  skipIfFrost,
  skipIfExtremeHeat,
}

class Reminder {
  // ...existing fields...
  WeatherAwareness weatherAwareness;
  // ...
}
```

### Photoperiod stage transitions

For outdoor + `useNaturalPhotoperiod = true`:

* Plant auto-flips from `vegetative` → `flowering` when local daylight
  hours drop below 13.5
* User can override (e.g. for autoflowering strains)
* Visible in Plant Detail: "Auto-flip expected in 12 days based on
  your latitude"

## UI changes

### Onboarding

Space creation flow gets an indoor/outdoor toggle as the first decision:

```
[ Indoor ]   [ Outdoor ]   [ Greenhouse ]
```

Outdoor branches diverge:
* Outdoor: requires latitude/longitude (auto-detected via GPS with
  permission, or manual entry)
* Greenhouse: hybrid — manual temperature targets but natural light

### Plant Detail

Outdoor plants show:
* Sun icon (vs. indoor lightbulb)
* "Daylight today: 11h 24m" widget
* Weather forecast strip (3-day, with rain/frost/heat highlights)
* Auto-flip countdown if `useNaturalPhotoperiod`

### Home screen

Outdoor spaces get a sun icon instead of the lightbulb. Status colours
unchanged.

### Reminders

Reminders with `weatherAwareness != none` show a small cloud icon:

```
[💧 Water Veg Tent]                  Today 9am
[💧 Water Outdoor #1]                Today 9am ☁️
   ↳ "Rain forecast — postpone?" prompt at scheduled time
```

## Implementation phases

1. **Phase 1 (Week 1):** Data model migrations + space creation UI
2. **Phase 2 (Week 1-2):** Outdoor weather card integration (already
   exists — extend to all outdoor spaces)
3. **Phase 3 (Week 2):** Photoperiod tracking + auto-flip
4. **Phase 4 (Week 2-3):** Weather-aware reminder logic

Ship as v1.0.x patches so the SA-specific story lands BEFORE v1.1.0.

---

# 📈 Yield prediction — technical spec

## Algorithm

Bayesian estimate combining three signals:

```
predicted_yield_g = strain_baseline_g
                  + user_history_adjustment_g
                  + environment_quality_adjustment_g

confidence_band  = stddev(predicted_yield_g)
```

### Strain baseline

```
strain_baseline_g = strain.expectedYieldPercent
                  * space.areaSqM
                  * 100         // g/m² baseline
                  * plant.count
```

For built-in strains, `expectedYieldPercent` is in the strain library.
For user strains: fallback to genre median (Indica/Sativa/Hybrid).

### User history adjustment

If user has previous runs of the same strain:

```
adjustment_g = avg(historical_runs.actual_yield_g)
             - avg(historical_runs.predicted_yield_g)
```

i.e. "this user typically over-/under-shoots predictions by X grams."
Weighted by recency.

### Environment quality adjustment

Reuses the existing `health_score_card` calculation:

```
adjustment_g = (health_score - 75) / 100
             * strain_baseline_g
             * 0.30           // up to ±30% impact
```

Health score 75 = neutral (no adjustment). 100 = +30%. 50 = -30%.

### Confidence band

Width depends on data depth:

| Data depth | Confidence band |
|---|---|
| No user history, builtin strain | ±25% |
| 1-2 historical runs of same strain | ±15% |
| 3+ historical runs of same strain | ±8% |

## UI

### Plant Detail (during flowering only)

Card under "Current cycle" section:

```
┌──────────────────────────────────────────────────┐
│ 📈 Predicted yield                                │
│                                                   │
│        67 g  ± 9 g                                │
│        87% confidence                             │
│                                                   │
│ ▸ Tap for breakdown                               │
└──────────────────────────────────────────────────┘
```

Tap expands to:

```
Strain baseline (Blue Dream, 0.9 m²):     +72 g
Your history (-8 g typical):              -8 g
Environment quality (health 82/100):      +3 g
─────────────────────────────────────────────────
Predicted:                                 67 g ± 9 g
```

### Pro Cloud gate

The historical adjustment + 8% confidence (3+ runs) is **Pro Cloud
only**. Free users get strain baseline ± 25% only.

Reasoning: this aligns with the "history + comparisons = Pro" pricing
philosophy already established.

### Marketing potential

Track an opt-in `prediction_accuracy_log`. After 6 months, publish
aggregate stat: "Kultivar's Pro Cloud yield predictions are within
10% of actual harvest 84% of the time." That's a sharable claim.

---

# Task breakdown

Detailed tasks tracked in the project's task list (#98–#122). Themes
+ counts:

| Theme | Tasks |
|---|---|
| Cross-device sync — encryption + storage | 4 |
| Cross-device sync — sync engine + protocol | 6 |
| Cross-device sync — UI + onboarding | 3 |
| Cross-device sync — testing | 2 |
| Outdoor mode | 6 |
| Yield prediction | 4 |

Total: 25 tasks. See task list for detailed scope per task.

---

# Timeline

Assuming v1.0 ships ~3 weeks from today:

| Week | What ships |
|---|---|
| v1.0.0 launch (Week 0) | Public launch on Play Store |
| Week 1 | v1.0.1 — bug-fix release from launch-week feedback |
| Week 2 | v1.0.2 — outdoor mode Phase 1 + 2 (toggle + weather card extend) |
| Week 3 | v1.0.3 — outdoor mode Phase 3 + 4 (photoperiod + weather-aware reminders) |
| Week 4 | v1.0.4 — yield prediction MVP |
| Week 5-9 | v1.1.0-rc — cross-device sync development |
| Week 10 | v1.1.0 — coordinated launch with marketing push |

Each weekly release is an incremental v1.0.x to keep "Updated X days
ago" hot on the Play Store. v1.1.0 = the marketing milestone.

---

# What's not in v1.1 (deferred to v1.2+)

* **Plant ID AI** — pest/deficiency detection from photos
* **iOS launch** — parallel track (LAUNCH.md month 2-3)
* **Community feed** — opt-in public grow report sharing
* **Strain price guide** — community-sourced regional pricing
* **Hardware integration** — Bluetooth sensors, smart sockets
* **Web app** — desktop dashboard for Pro Cloud
* **B2B / facility mode** — multi-grow commercial management

These are real and worth building. Just not now — v1.1 has enough
scope to ship cleanly.

---

*Last updated: 2026-05-31. Edits land here as scope evolves.*
