# Settle: Sleep Science Basis (ages 0–24 months)

The research behind Settle's prediction engine. **Scope: birth to 24 months only.** Research on older children (nap dropping at ages 3–5, preschool models) was deliberately left out.

Status: research notes, Oct 2026. Not medical advice. Have a pediatric sleep specialist review this before launch.

---

## 1. The core model: two processes

Sleep timing is explained by the **two-process model** (Borbély; Daan, Beersma & Borbély 1984):

- **Process S, sleep pressure (homeostatic).** Builds up while awake and drains away while asleep. Physiologically it's linked to sleep-promoting substances such as adenosine building up in the brain.
- **Process C, the body clock (circadian).** A roughly 24-hour rhythm, set mainly by light, that makes sleep easier at some times of day and harder at others.

Sleep happens when pressure is high enough relative to what the body clock allows at that time of day. Waking happens when pressure has drained low enough.

Standard adult form (exponential saturation):

```
awake:   S(t) = 1 − (1 − S₀)·e^(−t/τw)      pressure rises toward 1
asleep:  S(t) = S₀·e^(−t/τs)                pressure decays toward 0
```

Typical adult time constants: **τw ≈ 18.2 h** (rise) and **τs ≈ 4.2 h** (decay).
The rise constant varies with development; the decay constant is more stable within a species (Skeldon et al. 2014).

## 2. How babies differ from adults

### 2.1 Pressure builds and clears much faster
- Jenni & LeBourgeois (2006): the speed of sleep pressure **slows down across childhood**, so younger children build up pressure faster and can't stay awake as long. This is the scientific basis for short wake windows.
- Webb, Phillips & Roberts (2023, bioRxiv preprint): fitted an adult sleep model to longitudinal data from **2 to 540 days old**. They found developmental changes are *"consistent with a faster accumulation and faster clearance of sleep homeostatic pressure in infancy and a weaker circadian rhythm in early infancy."*
  - The clearance time constant (χ in their model) starts at **about 5–10 h** in the first months, levels off around **33 h after about day 120**, and reaches adult-like values (about 45 h) only **around day 280**, when that infant moved to one nap.
  - The rate of pressure build-up (μ) is high early on and then settles.
  - Changes in clearance coincided with **changes in the number of naps per day**. Nap transitions are driven by sleep pressure.
- **Product meaning:** a single "how fast this baby builds pressure" parameter, which changes with age, explains most of the shift from many naps to two to one. A simple engine with few parameters can model 0–24 months.

### 2.2 The body clock starts out almost absent
- **At birth the circadian influence is negligible** (Webb et al. 2023 and the studies they cite). Sleep is spread across day and night.
- **About 8 weeks:** a day-night cortisol rhythm appears. **About 9 weeks:** a melatonin rhythm appears, at the same time as **night sleep consolidates**. **About 10–11 weeks:** a body temperature rhythm follows (Joseph et al. 2015, n=35 full-term babies).
- Webb et al.: the body clock is weak for **roughly the first 100 days**, then strengthens. In their longest dataset, a stable two-nap pattern locked to clock time appeared **around day 120**.
- **Product meaning:** before about 3 months, predicting by clock time doesn't work. Predict only from "time since last sleep", and keep the language loose.

### 2.3 Babies are very sensitive to light
- Webb et al. found babies' body clocks are **more strongly delayed by light** than adults' (b ≈ 1 vs. 0.4 in adults) across the whole 0–18 month range.
- **Product meaning:** evening light pushes bedtime later. This is a legitimate, evidence-based tip ("dim the lights in the hour before bed, get daylight in the morning"), and a reason bedtime drifts.

### 2.4 Huge differences between babies
- In Webb et al., one infant moved to one nap at about day 280; another was still on two naps after day 500.
- Parent-driven schedules also changed the fitted parameters, compared with a dataset where parents didn't steer sleep.
- **Product meaning:** age defaults are only a starting point. Fitting to each baby is the product. Never present age charts as targets the baby should hit.

## 3. Reference norms (calibration targets)

Use these to calibrate and sanity-check the model, not as targets shown to parents.

| Source | Age | Total sleep per 24h |
|---|---|---|
| AASM consensus (Paruthi et al. 2016; endorsed by the AAP) | 4–12 mo | **12–16 h** including naps |
| AASM consensus | 12–24 mo | **11–14 h** |
| AASM consensus | < 4 mo | no recommendation (normal range too wide, too little evidence) |
| Galland et al. 2012 (meta-analysis of 34 studies) | infants | mean **12.8 h** (range 9.7–15.9) |
| Galland et al. 2012 | toddlers / preschool | mean **11.9 h** (range 9.9–13.8) |

Other patterns from Galland et al. 2012, ages 0–2:
- **Night wakings:** 0–3.4 per night at 0–2 months, falling to 0–2.5 at 1–2 years. Waking at night is normal at every age in this range.
- The **longest stretch of night sleep** grows from 0 to 2 years; the **number of naps** falls up to age 2.
- The **biggest change in total sleep happens in the first 6 months**.
- Studies from mainly Asian countries show about **1 h less sleep**, so the norms vary by culture.

## 4. Wake windows: what's actually known

- **There's no direct study showing that wake-window schedules improve infant sleep.** Pediatric sleep physician Craig Canapari says the idea has *"some basis in sleep science"* but is not taught or researched in pediatric sleep medicine. Popular wake-window charts are compiled from blogs, not studies.
- The science they loosely rest on is real: fast pressure build-up in babies (2.1) means short times awake.
- **Product meaning:** don't say "science-backed wake windows". Say "**predictions from a sleep-pressure model, fitted to your baby**". That's more honest and sets Settle apart from Napper. The usual wake-window ranges only serve as the starting values (priors) the model is calibrated against.

## 5. Proposed Settle engine: "simple sleep pressure"

The design aims for as few parameters as possible, every output explainable, and each part traceable to a finding above.

### 5.1 State
- `S`: sleep pressure, 0 to 1
- While **awake**: `S` rises toward 1 with time constant **τw(baby)**
- While **asleep**: `S` falls toward 0 with time constant **τs(baby)**
- The difference from adults is just much smaller τ values, which shrink less and less as the baby grows

### 5.2 When to sleep
- A **nap window opens** when `S` reaches the upper threshold `H⁺(t)`
- **From about 12 weeks**, the body clock sets the threshold by time of day. The v0 calibration puts the peak at about 6:15 pm (late-day alertness keeps the last wake window long), and the threshold falling after that peak is what brings on bedtime. The strength of this effect grows from 0 at 8 weeks to its full value around 16 weeks (from 2.2).
- The time to the next nap has a closed form, so there's nothing to simulate:

```
wake_window = τw · ln( (1 − S_after_last_sleep) / (1 − H⁺) )
```

**What this explains:** a short nap leaves pressure higher (`S_after_last_sleep` is larger), so the next wake window is automatically shorter. Napper probably needs hand-written rules for this; here it falls out of the physics. Car naps, catnaps and split naps are handled the same way.

### 5.3 Fitting to each baby
- Start from age-based priors: τw and τs calibrated so the model reproduces typical wake windows and total sleep for that age (section 3 and the wake-window ranges in SPEC §3.1)
- Update **τw** from the baby's logged wake times. Specifically, when a baby falls asleep easily, treat that as evidence the threshold was reached. Use recent days only (half-life of about 3 days) and **exclude off days** (sick, teething, travel).
- The fewer logs we have, the more weight the age prior gets (a simple Bayesian blend). New babies start out looking like the average baby and become themselves over a few days.

### 5.4 Nap transitions
- Simulate tomorrow with the current fitted parameters. When the simulated day **no longer fits N naps** between the morning wake and the bedtime window, suggest moving to N−1 naps. The parent decides; the change is never made silently.
- This matches Webb et al.: shifts in the pressure parameters coincided with nap-count changes.

### 5.5 Behavior by age band

| Age | Body clock | What Settle shows |
|---|---|---|
| **0–8 wk** | ~none | "Awake for 52m. Newborns often get sleepy within about an hour." Pressure only, no clock times, focus on feeding. **No paywall for predictions here.** |
| **8–16 wk** | emerging | Next nap window from pressure; a gentle *suggested* bedtime that gets stronger each week |
| **4–24 mo** | established | Full model: planned day, nap windows, bedtime, nap-transition suggestions |

### 5.6 Explanations (every prediction says why)
- "Last nap was short (28m) → pressure still high → shorter wake window."
- "Evening → body clock lowers the threshold → bedtime window 6:45–7:15."
- "Sick day flagged → using the earlier end of the window."

### 5.7 What we deliberately leave out
- Modeling the physiology of the sleep-wake switch (Phillips–Robinson type models): too many parameters, little gain at app scale
- Modeling light exposure: we don't measure light; it's only given as tips (2.3)
- Machine learning: not enough data per baby, and it can't explain itself

## 6. Calibration results (Oct 2026)

Tool: [`tools/calibrate/`](../../tools/calibrate/). Output: `out/report.md`, `out/bands.png`, `out/sweep.png`, `out/curve.json`.

**Attempt 1, a separate fit for each age band:** it hit every target almost perfectly (loss < 0.06 per band) but was **rejected**. The fitted settings jumped around between bands (τw 5.8 → 5.6 → 4.3 → 6.4 → 15.9 → 7.5 h) because the model has more free settings than the targets can pin down. Some bands also put the longest wake window in the morning, and the 12–15 month band wasn't a stable daily routine.

**Attempt 2, one age curve fitted to all bands (v0, rejected):** 8 global settings that change smoothly with age. Nap transitions emerged without being programmed in, but the fit landed on a **non-physiological** solution: pressure cleared more slowly than it built (τs ≈ 18 h vs. τw ≈ 4–15 h) and the thresholds nearly touched. A Swift engine test caught the result: after a normal 75-minute nap, a 7-month-old got a wake window of only **1.1 h**. The cause was that the fit only ever checked days the model ran by itself, never days where the parent decides how long naps last.

**Attempt 3, joint curve + "replay" check + τs < τw (adopted as v1 = `AgeCurve.v1`):** the replay check wakes the model at 7:00, takes the first nap at the predicted time, lets it run a typical length for the age, and requires the next wake window to land in the band's range. That's exactly how the app is used. A penalty also enforces τs < τw (pressure clears faster than it builds, as in adults).

| Setting | Value | Meaning |
|---|---|---|
| τw(age) | 7.76 h × (age / 52 wk)^0.276 | Pressure builds more slowly with age: **3.5 h at 3 weeks → 8.9 h at 19.5 months** |
| τs(age) | 5.08 h × (age / 52 wk)^0.129 | Clearance: **3.5 h → 5.4 h**, near the adult 4.2 h and faster in young babies (consistent with Webb et al.) |
| H0 / L0 | 0.376 / 0.206 | Fall-asleep / wake-up thresholds |
| A | 0.204, ramped from 0 at 8 wk to full at 16 wk | Strength of the body clock |
| φ | 16.66 (about 4:40 pm) | Threshold peak: the late-afternoon alertness peak |

Results:
- **Replay wake window after a typical nap:** 3–4 mo 1.1 h · 4–6 mo 1.8 h · 6–8 mo 3.0 h · 8–12 mo 3.8 h · 12–15 mo 4.7 h · 15–24 mo 4.5 h. These are plausible except 3–4 months, which is slightly short.
- **Nap transitions that emerge on their own:** 4 → 3 naps at about 3.7 mo, 3 → 2 at about 6.2 mo, 2 → 1 at about 16.6 mo.
- **Where it still misses when the model runs by itself (total loss 9.8):**
  - Night sleep too short at 3–4 mo (8.6 h) and too long at 6–8 and 15–24 mo (13–13.8 h)
  - Several bands still have the last wake window shorter than the first
  - Bedtimes are off by up to 1 h at some ages
- None of these misses affect next-nap predictions from today's logs. They do affect the "planned day" view and nap-transition suggestions, so those features wait for v2.

**Next calibration steps:**
1. Let the gap between thresholds change with age (affects total sleep in young babies)
2. Add a second harmonic to the body-clock curve (affects the timing of the single nap)
3. Simulate parents setting the morning wake time in the fit, since the targets assume they do
4. ~~Parity test against the Swift engine~~: done. `matchesPythonReference` in SettleCore checks 64 cases, and CI fails if the fixtures fall out of sync with `curve.json`.

## 7. Open questions and validation

1. **Calibrate the priors:** solve for age-specific τw, τs and H⁺ that reproduce section 3's totals and the typical wake-window and nap-count ranges. Do this offline, then hardcode a lookup table.
2. **How long naps last** is partly about sleep cycles, not just pressure. Before modeling it, verify the length of an infant sleep cycle against a primary source.
3. **"Put down" vs. "fell asleep":** time spent settling is time awake. Logging both improves the fit.
4. **Validation:** use backtesting. For each logged day, predict the next nap from the data before it and measure the error in minutes. Target a median error under 20 min (SPEC §8).
5. Get full texts: Jenni & LeBourgeois 2006 (exact rates), Paruthi 2016 (the note on babies under 4 months), Webb et al. (check whether a peer-reviewed version has been published since the 2023 preprint).

## Sources

- Daan, Beersma & Borbély (1984). Timing of human sleep: recovery process gated by a circadian pacemaker. *Am J Physiol* 246:R161–R183. (Adult τ values via [twoprocessmodel docs](https://twoprocessmodel.readthedocs.io/))
- Skeldon, Dijk & Derks (2014). [Mathematical models for sleep-wake dynamics](https://arxiv.org/pdf/1311.1734). *PLOS ONE*.
- Jenni & LeBourgeois (2006). [Understanding sleep–wake behavior and sleep disorders in children: the value of a model](https://pedpalascnetlibrary.omeka.net/items/show/13504). *Curr Opin Psychiatry*. See also [PMC2980811](https://pmc.ncbi.nlm.nih.gov/articles/PMC2980811).
- Webb, Phillips & Roberts (2023). [Mapping the physiological changes in sleep regulation across infancy and young childhood](https://www.biorxiv.org/content/10.1101/2023.11.16.567480v1.full.pdf). bioRxiv preprint (not peer reviewed).
- Joseph et al. (2015). [Getting rhythm: how do babies do it?](https://pubmed.ncbi.nlm.nih.gov/25245173/) *Arch Dis Child Fetal Neonatal Ed* 100:F50.
- Galland, Taylor, Elder & Herbison (2012). [Normal sleep patterns in infants and children: a systematic review](https://pubmed.ncbi.nlm.nih.gov/21784676/). *Sleep Med Rev* 16:213–222.
- Paruthi et al. (2016). [Pediatric sleep duration consensus](https://depts.washington.edu/dbpeds/pediatricsleepdurationconsensus.pdf). *J Clin Sleep Med* 12(6). [AASM summary](https://aasm.org/recharge-with-sleep-pediatric-sleep-recommendations-promoting-optimal-health/).
- Canapari. [Do wake windows help babies and kids nap better?](https://drcraigcanapari.com/wake-windows)
