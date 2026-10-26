# Settle

Settle predicts when a baby (0–24 months) will next be ready to sleep, using a sleep-pressure model fitted to that baby's logged sleep.

## Language

### The model

**Sleep pressure**:
A 0–1 score of how much need for sleep has built up. It rises while the baby is awake and drains while they sleep.
_Avoid_: sleepiness, tiredness score, sleep debt

**Body clock**:
The roughly 24-hour rhythm that makes sleep easier at some times of day than others. Babies are born with almost none, and it develops from about 8 weeks.
_Avoid_: circadian (in product copy), Process C

**Age curve**:
The model's settings expressed as smooth functions of the baby's age, fitted offline to published sleep norms.
_Avoid_: age table, wake-window chart, priors

**Sleep window**:
The predicted time range in which the baby's next sleep (a nap or night sleep) should start.
_Avoid_: nap window, sweet spot, nap time, next sleep

**Day plan**:
The predicted rest of today from now: the remaining naps and the start of night sleep.
_Avoid_: schedule, forecast, timeline

### Sleep

**Nap**:
A daytime sleep, between the morning wake and night sleep.

**Night sleep**:
The main overnight sleep, including brief night wakings.
_Avoid_: bedtime sleep, overnight

**Morning wake**:
The end of night sleep, which starts a sleep day.
_Avoid_: wake time, wake-up time

**Wake window**:
How long the baby is awake between the end of one sleep and the start of the next.
_Avoid_: awake time, wake time

**Sleep day**:
The period from one morning wake to the next. It's the unit for history and statistics, not the calendar date.
_Avoid_: day, calendar day

**Off day**:
A sleep day flagged as sick, teething, travel or vaccines. It's predicted conservatively and excluded from learning.
_Avoid_: bad day, exception

**Nap transition**:
A lasting move from N naps per day to N−1.
_Avoid_: nap drop, regression
