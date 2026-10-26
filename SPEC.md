# Settle: Product Spec (v1, sleep-first MVP)

> Name: **Settle** (formerly the working name "Nappi"). The trademark and App Store check is still to do; see [Risks](#9-risks).
> **Scope: babies aged 0–24 months only.** Older children are out of scope.
> Science basis: [docs/research/sleep-science.md](docs/research/sleep-science.md).

## 1. Positioning

**One line:** A sleep schedule app that tells parents when the next nap is, keeps working on messy days, never loses a log between two parents, and costs about a third of Napper.

Where we beat Napper (from competitor research, Oct 2026):

| Napper weakness (from reviews) | Our answer |
|---|---|
| Predictions drift during teething, illness, regressions or travel | "Off day" flags and fast re-planning; every prediction explains itself |
| Logs duplicated or lost when partners log at the same time | Local-first, append-only event log with client-generated IDs |
| A night that crosses midnight is split across two dates | Days run from morning wake to morning wake ("sleep day"), not by calendar date |
| Paused nursing sessions are hard to edit | Every event is editable, including segments inside it |
| Widgets show old data | Widgets read the same local store and refresh on every write |
| About $90–150/yr | Free logging and sync; predictions about $40/yr |

**Target user:** Parents of babies aged 0–24 months (out of scope at 24 months and older), often two caregivers, using the app one-handed in the dark at 3am.

## 2. V1 scope

### In
1. **Onboarding (under 60 seconds):** baby's name and birth date (with an optional due date to correct for prematurity), usual morning wake time, current number of naps. That's enough to predict on day 1.
2. **Logging**
   - Sleep: start/stop timer or manual entry; nap vs. night is inferred and can be overridden; optional "fell asleep at" time separate from "put down at"
   - Night wakings, logged inside a night
   - Feeds: breast (left/right timer with pauses), bottle (amount, breast milk or formula), solids (free text)
   - Diapers: wet / dirty / both
   - Every event can be edited and deleted; undo is shown as a snackbar
3. **Today screen:** current state ("Awake 1h 12m", "Napping 34m"), next predicted nap or bedtime with a window (e.g. 1:40–2:05 pm), and a timeline of today's events
4. **Predictions:** see [section 3](#3-prediction-engine)
5. **Notifications:** "Nap window opens in 15 min" (lead time is configurable), plus a bedtime reminder
6. **Caregiver sync:** invite by link or code; real-time updates; works offline
7. **History:** a 7-day sleep chart and a list view grouped by sleep day
8. **Night mode:** automatic after bedtime; very dark, warm or red tint, big tap targets, minimal animation
9. **Paywall:** predictions after a 7-day trial; logging, sync and history always free

### Out (v2 and later)
Sleep sounds and white noise · sleep course and articles · AI chat · sleep-training plans · Apple Watch · Live Activities / Dynamic Island · growth, milestones and vaccines · pumping · multiple children (keep it in the data model, hide it in the UI) · data export for the pediatrician · Nanit/Owlet import · Android release

## 3. Prediction engine

The approach is a **simple sleep-pressure model** (a two-process model with time constants that change with age), fitted to each baby. It runs entirely on the device and is deterministic, so it's easy to explain and to test. The full rationale and equations are in [sleep-science.md §5](docs/research/sleep-science.md#5-proposed-settle-engine-simple-sleep-pressure). The age table below now serves only as **calibration targets and starting values** for the model; the rules in 3.2 are what the model produces on its own, not separate hand-written rules.

### 3.1 Age defaults (starting values and calibration targets)
Use corrected age when the baby was premature. These are common published guidelines, **not medical advice**. Have a pediatric sleep consultant review them before launch.

| Age | Naps | Wake window | Target total daytime sleep |
|---|---|---|---|
| 0–6 wk | 4–6 | 45–60 min | flexible |
| 6–12 wk | 4–5 | 60–90 min | 4–6 h |
| 3–4 mo | 4 | 75–120 min | 3.5–5 h |
| 4–6 mo | 3 | 1.75–2.5 h | 3–4 h |
| 6–8 mo | 2–3 | 2.25–3 h | 2.5–3.5 h |
| 8–12 mo | 2 | 2.75–3.75 h | 2–3 h |
| 12–15 mo | 1–2 | 3.5–4.5 h | 2–3 h |
| 15–24 mo | 1 | 4.5–6 h | 1.5–2.5 h |

Wake windows usually get longer through the day: the first is the shortest and the last (before bed) is the longest.

### 3.2 Personal adaptation
For each slot (wake window #1, #2, … and the one before bed):
- Blend the age default with the baby's recent **actual** wake windows from the last 7 sleep days, weighted by how recent they are (half-life of about 3 days). Ignore days flagged as off days.
- **Nap-quality correction:** a short nap (under 40 min) shortens the next window by 10–20%; a long nap lets it stretch toward the top of the age range.
- **Day-level constraints:** the predicted bedtime is clamped to the parent's target bedtime range, and the last nap is dropped or shortened when it would push bedtime too late.
- **Nap transition detection:** when the last nap is skipped or fought on 3 or more of the last 5 days, suggest moving to one fewer nap. It's a prompt the parent accepts, never a silent change.
- **Output:** a window (earliest to latest), not a single minute, plus a plain-language reason: *"Short nap (32m) → shorter wake window today."*

### 3.3 Off days
A one-tap flag for a sleep day: 🤒 sick · 🦷 teething · ✈️ travel / time zone · 💉 vaccines.
- Predictions use the shorter end of the windows that day and the following day
- Flagged days are left out of the learning data
- Travel shifts the schedule toward the new time zone over 2–3 days

### 3.4 Tests
The engine is a pure function `(child, events, flags, now) → Prediction`. Build a set of test fixtures from synthetic and anonymized real logs, and test them in CI. That gives us a measurable "prediction error in minutes" score for comparing changes.

## 4. Data model

```
Family      { id, name, createdAt }
Caregiver   { id, familyId, displayName, role: owner|member }
Child       { id, familyId, name, birthDate, dueDate?, targetBedtime, targetWake }
Event       { id (UUID made on the device), childId, type, startAt, endAt?,
              payload (by type), createdBy, createdAt, updatedAt, deletedAt? }
  type = sleep | waking | feed_breast | feed_bottle | feed_solid | diaper
DayFlag     { id, childId, sleepDayDate, kind }
```

- **Sleep day** = from the morning wake to the next morning wake. Its date is the date of that morning wake. It's computed, not stored.
- **Running timers** are just events with `endAt = null`. Two caregivers see the same running timer.
- Times are stored in UTC along with the time zone they were logged in, so travel displays correctly.

## 5. Sync

- **Local-first:** the local database is the source of truth, and the UI never waits for the network.
- **Append-only with soft deletes:** IDs are made on the device, so two people logging at the same time create two distinct events, never a merge conflict. If both edit the same event, the later edit wins for each field (`updatedAt`).
- **Duplicate guard:** when two `sleep` starts for the same child land within 2 minutes of each other from different caregivers, show "Looks like you both logged this. Merge?"
- **Schema versioning:** every write carries the schema version, and old clients are told to update instead of silently writing bad data. This is the problem Napper's developer blamed on mixed app versions.

Backend options depend on the stack (section 6).

## 6. Stack decision: **native SwiftUI** (decided 2026-10-26)

Chosen: **B**, native SwiftUI. Builds and tests run on GitHub macOS runners (`macos-26`, Xcode 26.6). The engine is a pure Swift package (`Packages/SettleCore`) that also builds and tests on Linux. The sync backend (CloudKit vs. other options) is still open. See `docs/ci.md`.

Original comparison:

| | **A. Expo / React Native** | **B. Native SwiftUI** |
|---|---|---|
| Develop from this Linux machine | ✅ Expo Go on the iPhone; cloud iOS builds through EAS | ❌ needs a Mac with Xcode |
| Local database | expo-sqlite (+ Drizzle) | SwiftData / GRDB |
| Sync backend | Supabase (Postgres + realtime + auth); or PowerSync / ElectricSQL for local-first | CloudKit with sharing (free, private, nothing to run) |
| Widgets / Live Activities / Watch | Possible, but they're written in Swift anyway (`expo-apple-targets`) | First-class |
| Android later | Nearly free | Separate app |
| Privacy story | Data goes through our server | "Your data stays in your iCloud" |

**Recommendation:** If no Mac is available, use **A**. Write the prediction engine in plain TypeScript with no dependencies so it's portable, and add the Swift widget target in v1.1. If a Mac is available, **B with CloudKit** gives the best iOS feel and privacy story with no server to run, but no Android.

## 7. Pricing

- **Free:** all logging, caregiver sync, history, night mode
- **Nappi Plus:** predictions, notifications, off-day re-planning, trends. About **$4.99/mo or $39.99/yr**, with a 7-day trial. Consider a **$79 lifetime** plan; parents only need it for about 2 years per child, and "no subscription" is a real selling point.
- One subscription covers the whole family. Use Family Sharing on iOS and caregiver invites in the app.

## 8. Milestones

| # | Goal | Rough size |
|---|---|---|
| M0 | Stack decision, name check, project skeleton | days |
| M1 | Local logging, Today screen, history, night mode on one device | 2–3 wks |
| M2 | Prediction engine with test fixtures, notifications | 2 wks |
| M3 | Caregiver sync and invites | 2–3 wks |
| M4 | Paywall (StoreKit 2 / RevenueCat), onboarding polish | 1 wk |
| M5 | TestFlight beta with 20–50 families; measure prediction error and daily logging retention | 3–4 wks |
| M6 | App Store launch | — |

**Success metrics for the beta:** D7 retention of at least 60% · at least 5 logs per day per active family · median prediction error under 20 min · trial-to-paid conversion of at least 15%.

## 9. Risks

- **Name / trademark:** "Settle". A quick web search found no baby app with that name (only a small Android "Settle Timer"). Still do a full search of the USPTO (classes 9 and 44), EUIPO and the App Store on an iPhone, plus domains and social handles.
- **Science claims:** there's no direct evidence that wake windows improve sleep. Market "a sleep-pressure model fitted to your baby", never "science-backed wake windows".
- **Medical claims:** never say "medical", "diagnose" or "safe sleep monitor". Present the guidance as general information, show a disclaimer, and have it reviewed by a sleep consultant.
- **Privacy:** the data is about children and health. Under GDPR (EU) it's likely special-category health data. Keep collection to a minimum, no ad SDKs, offer export and deletion in the app, and write accurate App Store privacy labels.
- **Napper's lead:** 100k+ families and a 4.9★ rating. We need a sharp wedge (reliability, messy days, price), not just feature parity.

## 10. Open questions
1. ~~Is a Mac available?~~ → native SwiftUI, built in CI on macOS runners
2. ~~Final name?~~ → **Settle** (trademark check still to do)
3. Solo indie project or a company or team? This affects backend choices and legal setup.
4. Launch region: US first, or EU too (GDPR and localization)?
