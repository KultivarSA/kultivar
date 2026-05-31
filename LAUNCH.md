# Kultivar — 90-day launch plan

This is a living document. Edit the dates as reality slips; keep the
*shape* of the cadence intact. The point is: a deliberate sequence
where each phase compounds on the previous one.

> **Audience note.** This plan is calibrated for a solo / very-small-team
> launch with no paid marketing budget in month one. Every tactic here
> is either free or sub-£100. If you raise / hire, the cadence stays
> the same but the volume scales.

> **Platform phasing (decided).** Kultivar launches **Android-only first**
> on the Play Store. iOS follows as a Month 2-3 milestone once Play
> revenue has covered the Mac + Apple Developer membership. See
> `LAUNCH_ANDROID.md` for the week-by-week Android execution checklist
> and the section "Month 2-3 — iOS launch" further down this file for
> the iOS phase plan. **The 90-day plan below is Android-only**;
> dual-store references have been removed.

---

## Strategic posture

**You are not selling a grow tracker.** You are selling the *grower's
private journal* — the one that doesn't ask for an email, doesn't
spy on photos, and makes them look serious in front of their friends
when they share a Grow Report PDF.

That positioning is the whole ASO + content + community strategy. If
you say "track your plants" you're commodity. If you say "the journal
serious growers keep on their own device" you're a category of one.

Three pillars to repeat in every channel:

1. **Private by default** — no account, no cloud forced on you
2. **Built like a real app** — design quality, dark theme, animations,
   accessibility
3. **Made for the whole world** — 9 languages including Afrikaans + Zulu

Don't say "cannabis" in ad copy or the App Store title (Apple rejects
it). Say "grow journal", "plant tracker", "cultivation log". Your
target audience self-selects.

---

## Pre-launch  (T-30 → T-0)

The 30 days before your first store-listing is live.

### Week T-4: Final product gates (Android)

- [ ] Run `pwsh ./tools/preflight.ps1` until all 6 checks pass
- [ ] Get the Zulu + Afrikaans ARB files reviewed by a native speaker
      (post in r/SouthAfrica, r/Afrikaans, r/Zulu — offer £50 / R1000
      for a half-day review of ~180 strings)
- [ ] Provision Google Play Console (£25 one-time). Apple Developer
      is **deferred to Month 2-3** — see the iOS section below
- [ ] Set up RevenueCat (Android products only initially) with the
      ZAR pricing tier
- [ ] Generate Android upload keystore + wire
      `android/key.properties` + `android/app/build.gradle` signing
      config. See `LAUNCH_ANDROID.md` for the full keystore walkthrough
- [ ] Manual Android screenshots via Pixel 8 Pro emulator +
      `store_metadata/play_console/screenshots_playbook.md`
- [ ] iOS Fastlane snapshot + Apple review notes **stay parked**
      ready to go. No work needed on the iOS side this phase

### Week T-3: Public surface prep

- [ ] Buy `kultivar.app` (or whatever domain). Point it at the GitHub
      Pages `/docs` folder OR a Carrd one-pager that links to the App
      Store + Play once live
- [ ] Create dedicated Instagram + TikTok handles (`@kultivar.app`)
- [ ] Create dedicated Twitter/X handle (cannabis content is allowed
      on X; useful for grower-community reach)
- [ ] Reserve subreddit name `r/kultivar` (Reddit lets you sit on a
      sub-name without populating it). You'll seed it in month 2.
- [ ] Set up a Discord server (free) — invite-only at first
- [ ] Set up a transactional-email account (e.g. Resend, free tier)
      for the support@ inbox you'll point store listings to

### Week T-2: Content stockpile

Pre-produce ~10 pieces of content so launch week isn't a content
panic:

- [ ] 1 × 60-second "what is Kultivar" hero video (screen-recording
      + light voiceover; you don't need to be on camera). Re-cut for
      Instagram Reels, TikTok, YouTube Shorts, Twitter video
- [ ] 5 × Instagram still posts: dark-theme screenshot + tagline +
      grower-relevant copy. Schedule one per week
- [ ] 3 × longer-form thread/blog posts:
  - "Why we built a grow tracker that doesn't want your email"
  - "Cost-per-gram: the metric every home grower should know"
  - "What the Cannabis for Private Purposes Act (SA) means for hobby
    growers — and why a private journal matters"
- [ ] 1 × Show HN draft (Hacker News). Title: *Kultivar — offline-first
      grow journal for home gardeners, built with Flutter*. HN
      audience cares about privacy + Flutter; less so about cannabis,
      which is fine — the tech-quality lede leads
- [ ] 1 × Product Hunt draft (launch on Tuesday for best traffic)

### Week T-1: Soft launch dry run (Android only)

- [ ] Submit to Play **Internal Testing track only** (instant
      activation — invite 5 testers via Play Console by email)
- [ ] Get 5 trusted growers (Discord / Telegram / WhatsApp contacts)
      onto the Internal Test build
- [ ] Watch them complete an onboarding → harvest cycle. Log every
      moment of friction. Patch only the showstoppers; everything
      else goes into the v1.0.1 backlog
- [ ] Verify the in-app review prompt fires correctly on
      `Grow Report → Share` (see Task #87)

### Day 0: Submit to Play production

- [ ] Play submission to Production track
- [ ] Set release rollout to **20% staged** initially — gives you
      48-72h to spot field crashes before full distribution
- [ ] Complete the Restricted Content cannabis declaration with the
      exact text from `store_metadata/play_console/app_content_declarations.md`
- [ ] Complete Data Safety form (same source file)
- [ ] Complete content rating (IARC) questionnaire — answers in same file

> Google Play typically approves cannabis-tracker apps within 3-7
> days first submission when the Restricted Content declaration is
> filled correctly. Plan for a 7-day window between submission and
> going public.

---

## Launch week  (Days 1–7)

You only get one Day 1. Use it.

### Day 1 (Tuesday recommended)

Order matters here — front-load the channels where momentum compounds.

**Product Hunt and Hacker News are deliberately HELD for the iOS
launch in Month 2-3.** Their audiences skew iOS-heavy and they're
scarce launch ammunition. Burning them on an Android-only launch
gets weak signal; saving them for a dual-platform "now on iOS too"
moment gets a much stronger second wave.

| Time (your local) | Channel | Tactic |
|---|---|---|
| 08:00 | Twitter/X | Tweet thread linking Play Store + the LAUNCH plan reasoning. Pin it |
| 09:00 | Instagram + TikTok | Drop the 60-second hero video |
| 10:00 | LinkedIn | Founder post — angle is "shipped a Flutter side project targeting the SA + EU markets, Android-first to validate before iOS." Keeps it tech-credible |
| 11:00 | r/microgrowery | "I built an offline-first grow journal for Android — feedback wanted" post.  **Read the rules first.** Mods tolerate occasional self-promo from active community members; lurk + comment for 2 weeks before this if you haven't already |
| 13:00 | SA Facebook groups | Cannabis-grower groups (search "South Africa cannabis grow" — there are several with 5-20k members each). Polite intro, link to Play |
| 14:00 | SA WhatsApp grower groups | Drop a one-line intro + Play link. Less performative, more direct than Reddit |
| 16:00 | Discord cannabis grower servers | Drop a polite intro in the off-topic / self-promo channel of 3–4 servers you've been active in |
| 18:00 | YouTube comments | Comment on 5-10 recent grow-journal videos with substantive feedback + one line about Kultivar. Don't spam — engage genuinely |

**Don't post in r/cannabis or major weed subreddits on day 1.** Their
mods aggressively remove anything that smells like product launches.
Lurk longer there.

**SA-specific channels matter more for Android launch.** Android share
in SA is 85-90%, so SA-focused channels (Facebook groups, WhatsApp,
local cannabis publications) deliver disproportionate ROI vs. global
Reddit / Twitter.

### Days 2–4: respond to everything

- Reply to every PH / HN / Reddit / IG comment within 6 hours
- Treat every negative comment as a bug report — even if it's wrong,
  the public reply is content for everyone else watching
- Take screenshots of any positive press / reviews. You'll use them
  as Instagram stories for weeks

### Days 5–7: first iteration sprint

- Triage the bug reports / feedback from the launch week
- Ship a v1.0.1 with the top 3 paper-cut fixes (toast wording, an
  obvious copy bug, a layout fix on some specific device)
- Filing a v1.0.1 in week 1 looks shockingly more responsive than
  most apps — it's a free trust-builder

**Success criteria for week 1:** 200 downloads, 3 store reviews,
1 mention from a grower-community account, 1 piece of unsolicited
content (someone showing your app on their channel without you
asking).

---

## Weeks 2–4: early momentum

Now you're in the long game. The launch-week spike will decay; your
job is to put a floor under it.

### Weekly cadence

- **Tuesday**: Ship a v1.0.x with one improvement. Even a tiny one.
  The store-listing "Updated X days ago" is a signal to users that
  the developer is alive
- **Thursday**: Post on Instagram / TikTok. Rotate between:
  - Screenshot + tagline
  - 15-sec "did you know Kultivar can…" feature spotlight
  - User testimonial (with permission)
- **Sunday**: Long-form post somewhere — Reddit, Twitter thread,
  Discord recap

### Specific reach tactics

- **Reach out to 3 grow-content YouTubers per week.** Offer them a
  free Pro Cloud account in exchange for honest review. Don't pay
  for reviews — Apple will pull listings caught doing this. ~3% will
  respond; that's enough
- **List on AlternativeTo.net** under "GrowBuddy alternatives" —
  free directory, decent SEO juice
- **Submit to Reddit's `/r/iosapps` weekly thread** — moderated but
  fair to indie apps with a clear pitch
- **Hacker News follow-up** in week 3 with a Show HN-style "what I
  learned shipping a Flutter app to 9 locales including isiZulu"
  post. Different angle = different ranking
- **Capture 5 testimonials** from users who completed a harvest in
  the app. Use them in App Store screenshots after week 6

### Important: respond to App Store reviews

- Reply to every 1- and 2-star review within 48 hours, publicly
- Reply to every 4- and 5-star review with thanks
- This is one of the only ASO levers Apple publishes — Apple's own
  guidance says responding to reviews improves store ranking

### Watch the metrics

- Daily installs by country (App Store Connect + Play Console)
- Where are reviews coming from? Lean into geographic momentum
- Free-to-Pro conversion rate. If it's < 2% in week 4, your paywall
  copy needs work (not your features)
- D7 retention. If it's < 35% by week 4, onboarding has a leak

---

## Weeks 5–8: iterate based on data

By now you have ~500–2,000 users (target band — wider is fine). Real
patterns emerge.

### Mid-cycle ship: v1.1.0

Most reviews / feedback by week 4 will cluster around 3–4 themes.
Common ones for grow apps:

1. *"Why can't I do X on the home grid?"* → home customisation
2. *"I want to track outdoor grows"* → outdoor mode (weather-driven
   reminders instead of timer-driven)
3. *"I want my data on my tablet too"* → cross-device sync (already
   on Pro Cloud roadmap)
4. *"Can it identify pests?"* → plant ID AI (the one feature
   competitors have; consider tflite-based for v1.2)

Pick the top one and ship v1.1.0 in week 7. Promote heavily:

- App Store "What's New" — write *user-focused* copy ("Now: spot a
  bug in 2 seconds with photo deficiency hints") not engineer-focused
  ("Migrated to fl_chart 1.0")
- Instagram + TikTok announcement
- Email to early testers (use the support@ inbox you set up)

### Begin community building

- **Open r/kultivar** — even with 50 members, an active subreddit
  is a referral magnet. Pin a "welcome — feature requests welcome"
  post. Reply to every comment for the first 2 months yourself
- **Open Discord to public** — same logic. A 30-person Discord with
  daily activity beats a 3,000-person one with weekly activity
- **Newsletter** — a monthly "what shipped + what's coming" email
  works wonders for re-engagement. Resend free tier is plenty

### Press outreach (cautiously)

The cannabis-app vertical doesn't have a clear set of press outlets.
Don't waste cycles pitching general tech press. Do pitch:

- Leafly's "Cannabis 101" / "Strain Guide" editorial — they
  occasionally cover apps
- High Times (still publishing, dwindling but real reach)
- Local SA cannabis publications post Act 7 (Cannabiz Africa, The
  Bluntness Africa)

---

## Weeks 9–12: compound + plan v1.2

If weeks 1–8 went well, you're now in compound mode. The work shifts
from "find users" to "deepen the existing user relationship".

### Ship v1.1.x updates weekly

- 10-minute bug-fix releases
- Each release reinforces "this app is alive" — most competitors
  ship monthly or less

### Plan the year-1 roadmap

By now you know what users want. Lock the v1.2 roadmap to a
quarterly cadence:

- **Q1 of year-1 (months 0–3)**: launch, polish, react
- **Q2**: cross-device sync (Pro Cloud killer feature)
- **Q3**: plant ID AI (the competitor parity feature)
- **Q4**: outdoor mode or another headline feature based on data

### Lock in the SA story

The SA market has the cleanest "you own it" narrative right now. By
the end of month 3:

- Pursue at least one published case study with a SA grower
- Submit a talk to a cannabis-industry conference (CannaTech SA,
  Cannabis Expo Africa, etc.)
- Aim for 50%+ of organic SA installs being conversion-to-Pro Cloud
  — the ZAR pricing tier should be optimised for affordability vs.
  US/EU pricing

---

## What "winning" looks like at day 90

Concrete success criteria. If you hit these, you've earned a v1.2
sprint:

| Metric | Floor | Stretch |
|---|---|---|
| Total installs | 2,000 | 10,000 |
| Active users (D7) | 35 % | 50 % |
| App Store rating | 4.3 ★ | 4.6 ★ |
| Reviews (combined) | 50 | 200 |
| Free → Pro conversion | 2 % | 5 % |
| Subreddit / Discord members | 50 | 500 |
| SA share of installs | 15 % | 30 % |

Below the floor on multiple rows? The product needs work, not more
marketing.

Above the stretch? Time to think seriously about hiring help, going
to investors, or both.

---

## Month 2-3: iOS launch (the second wave)

The Android launch validates demand; iOS is the **scale move**. Don't
think of it as a Day-2 catch-up — it's a second launch with its own
playbook.

### When to trigger the iOS phase

Trigger conditions (all three, not any):

1. ≥ 1,000 Android installs accumulated
2. Play store rating ≥ 4.3 ★ with ≥ 20 reviews
3. Either (a) Pro Cloud + Lifetime Local revenue covers the £700
   Mac + £79 Apple Developer cost, OR (b) you've decided to fund
   it from personal budget with no further proof needed

If you hit those before Day 60, accelerate. If not until Day 90+,
that's fine — the playbook waits.

### iOS launch prep checklist

- [ ] Buy Mac mini M4 (cheapest viable Xcode + Fastlane workstation,
      ~£600 / R14k). Even the base 16GB / 256GB SSD model is
      sufficient — no need for the higher tiers
- [ ] Provision Apple Developer Program (£79/year, takes 24-48h)
- [ ] Open `ios/Runner.xcworkspace` in Xcode, add `RunnerUITests`
      target if Xcode hasn't auto-created one (see BUILD.md SR9)
- [ ] `cd ios && fastlane snapshot init` — writes
      `SnapshotHelper.swift` next to the test driver
- [ ] `cd ios && fastlane screenshots` — captures all 3 devices ×
      9 locales (~25 min on M-series)
- [ ] Fill `<REVIEW_*>` placeholders in
      `store_metadata/ios/en-US/review_information/` with your real
      contact details (the pre-flight script will surface any you
      missed)
- [ ] Submit to App Store Connect with the pre-drafted review notes
      already in place
- [ ] **Expect a rejection.** Cannabis apps get pushed back on
      first submission ~30-50% of the time per Apple §1.4.3. The
      pre-drafted notes minimise the risk but don't eliminate it.
      Respond to any rejection within 24h citing the comparable
      approved apps (GrowBuddy / Plant Diary / Strain Genie) again

### iOS launch Day 1 channel mix

This is where Product Hunt + Hacker News come out of the freezer:

| Time | Channel | Angle |
|---|---|---|
| 06:00 | Product Hunt | "Kultivar — now on iPhone. Offline-first grow journal, 9 locales, ZAR pricing for the SA market" |
| 07:00 | Hacker News Show HN | "Show HN: Kultivar on iOS — Flutter app, 12-week Android-first launch reflections" |
| All day | Re-engagement push | Email your support@ list + Instagram + Twitter audience announcing "now on iOS" — this is the only platform-launch *content* you can credibly do twice |

### Don't lose the SA Android focus

While iOS is launching, **don't take your eye off Android**. 85% of
SA users will still be on Android long after iOS ships. Keep
shipping Android updates on the same Tuesday cadence.

---

## What to **not** do in the first 90 days

- ❌ Paid Facebook / Instagram ads. Cannabis content on those
  platforms is a moderation lottery — you'll burn money and risk
  account bans
- ❌ App Store ads (Apple Search Ads). Cannabis terms are blocked.
  Generic "grow tracker" terms are too broad to convert
- ❌ Influencer-pay arrangements. Apple will pull listings caught
  paying for reviews
- ❌ Pivot the positioning. "Grower's private journal" is the moat.
  Don't dilute it by chasing "grow social network" or "AI plant
  doctor" early — those are v2 conversations
- ❌ Build the SA market and *then* turn to Europe. Run both in
  parallel from week 1; SA is your beachhead, EU is your scale

---

## Adjacency notes — things worth knowing

- **The cannabis app graveyard is huge.** Most fail because they
  pivoted to social or to commerce. Stay in journal-tool lane
- **Reddit cannabis subs hate self-promo.** Build credibility through
  participation FIRST. Two months of meaningful comments + then a
  post is worth more than ten launch posts ignored
- **The Play Store has a stricter cannabis policy review than Apple.**
  Your `store_metadata/play_console/app_content_declarations.md` is
  pre-drafted — paste it exactly. Don't improvise
- **iOS rejections are nearly always copy-fixable.** If reviewer pushes
  back, the response is to amend the App Privacy answer or the
  description, not to remove the feature

---

*Last updated: 2026-05-30. Edit as the world moves — the cadence is
the point, not the calendar precision.*
