"""Settle sleep-pressure model (two-process model, infant time constants).

Units are hours. Clock time t=0 is midnight of day 0.

    awake:  S rises toward 1 with time constant tau_w
    asleep: S decays toward 0 with time constant tau_s
    fall asleep when S >= H(t) = H0 + A*C(t)
    wake up     when S <= L(t) = L0 + A*C(t)
    C(t) = cos(2*pi*(t - phi)/24)        circadian drive, peaks at hour phi

See docs/research/sleep-science.md section 5.
"""

from dataclasses import asdict, dataclass
from itertools import pairwise

import numpy as np

DT = 1 / 60  # 1-minute resolution
LOOKAHEAD_H = 30.0
LOOKAHEAD = np.arange(1, int(LOOKAHEAD_H / DT) + 1) * DT


@dataclass
class Params:
    tau_w: float  # pressure rise time constant while awake (h)
    tau_s: float  # pressure decay time constant while asleep (h)
    H0: float  # upper threshold, mean
    gap: float  # H0 - L0
    A: float  # circadian amplitude
    phi: float  # clock hour where both thresholds peak

    @property
    def L0(self) -> float:
        return self.H0 - self.gap

    def H(self, t):
        return self.H0 + self.A * np.cos(2 * np.pi * (t - self.phi) / 24)

    def L(self, t):
        return self.L0 + self.A * np.cos(2 * np.pi * (t - self.phi) / 24)

    def as_dict(self) -> dict:
        d = asdict(self)
        d["L0"] = self.L0
        return d


@dataclass
class AgeCurve:
    """Global model: one parameter set that varies smoothly with age (weeks).

    tau_w, tau_s grow as power laws of age (pressure dynamics slow with age:
    Jenni & LeBourgeois 2006; Webb et al. 2023). The circadian amplitude ramps
    0 -> A_max between 8 and 16 weeks (cortisol ~8 wk, melatonin ~9 wk,
    clock-locked naps ~day 120: Joseph et al. 2015; Webb et al. 2023).
    """

    tau_w_52: float  # tau_w at 52 weeks (h)
    k_w: float  # power-law exponent for tau_w
    tau_s_52: float
    k_s: float
    H0: float
    gap: float
    A_max: float
    phi: float

    def at(self, age_wk: float) -> Params:
        r = age_wk / 52
        ramp = min(max((age_wk - 8) / 8, 0.0), 1.0)
        return Params(self.tau_w_52 * r**self.k_w, self.tau_s_52 * r**self.k_s, self.H0, self.gap, self.A_max * ramp, self.phi)


def simulate(p: Params, days: int = 10, t0: float = 7.0):
    """Free-running simulation. Returns list of (sleep_start, sleep_end) or None if degenerate."""
    t, S, awake = t0, float(p.L(t0)), True
    bouts, start = [], None
    end_t = days * 24
    while t < end_t:
        grid = t + LOOKAHEAD
        if awake:
            Sg = 1 - (1 - S) * np.exp(-LOOKAHEAD / p.tau_w)
            cross = Sg >= p.H(grid)
        else:
            Sg = S * np.exp(-LOOKAHEAD / p.tau_s)
            cross = Sg <= p.L(grid)
        if not cross.any():
            return None  # stuck awake or asleep for 30h
        i = int(np.argmax(cross))
        t, S = float(grid[i]), float(Sg[i])
        if awake:
            start = t
        else:
            bouts.append((start, t))
        awake = not awake
        if len(bouts) > days * 20:
            return None  # chattering
    return bouts


def next_sleep(p: Params, t_now: float, S_now: float) -> float:
    """What the app calls: hours until the next sleep window opens, from pressure S_now at clock t_now."""
    grid = t_now + LOOKAHEAD
    Sg = 1 - (1 - S_now) * np.exp(-LOOKAHEAD / p.tau_w)
    cross = Sg >= p.H(grid)
    return float(LOOKAHEAD[np.argmax(cross)]) if cross.any() else float("nan")


def pressure_trace(p: Params, bouts, t_from: float, t_to: float, t0: float = 7.0):
    """S(t) on a minute grid, replaying the bouts (for plots)."""
    ts = np.arange(t0, t_to, DT)
    S = np.empty_like(ts)
    s, awake, k = float(p.L(t0)), True, 0
    edges = [e for b in bouts for e in b]
    last = t0
    for i, t in enumerate(ts):
        while k < len(edges) and t >= edges[k]:
            s = _advance(p, s, awake, edges[k] - last)
            last, awake, k = edges[k], not awake, k + 1
        S[i] = _advance(p, s, awake, t - last)
    m = ts >= t_from
    return ts[m], S[m]


def _advance(p, s, awake, dt):
    if awake:
        return 1 - (1 - s) * np.exp(-dt / p.tau_w)
    return s * np.exp(-dt / p.tau_s)


def metrics(bouts, days: int = 10, last: int = 3, consolidated: bool = True) -> dict | None:
    """Daily summary over the last `last` days. A day runs 04:00 to 04:00."""
    keys = ("tst", "bouts", "naps", "night", "day_sleep",
            "ww_first", "ww_last", "ww_mean", "ww_min", "ww_max", "ww_rise", "bedtime", "wake")
    out = {k: [] for k in keys}
    for d in range(days - last, days):
        w0, w1 = d * 24 + 4, (d + 1) * 24 + 4
        tst = sum(max(0.0, min(e, w1) - max(s, w0)) for s, e in bouts)
        day_bouts = [(s, e) for s, e in bouts if w0 <= s < w1]
        out["tst"].append(tst)
        out["bouts"].append(len(day_bouts))
        gaps = [b[0] - a[1] for a, b in pairwise(bouts) if w0 <= b[0] < w1]
        if not consolidated:
            out["ww_mean"].append(np.mean(gaps) if gaps else np.nan)
            continue
        # night = longest bout starting 16:00..04:00 in this window; previous night = the one before
        nights = [b for b in bouts if (d * 24 + 16) <= b[0] < w1]
        prev = [b for b in bouts if (d * 24 - 8) <= b[0] < w0]
        if not nights or not prev:
            return None
        night = max(nights, key=lambda b: b[1] - b[0])
        prev_night = max(prev, key=lambda b: b[1] - b[0])
        morning = prev_night[1]
        naps = [b for b in bouts if morning <= b[0] < night[0]]
        seq = [prev_night] + naps + [night]
        ww = [b[0] - a[1] for a, b in pairwise(seq)]
        out["naps"].append(len(naps))
        out["night"].append(night[1] - night[0])
        out["day_sleep"].append(sum(e - s for s, e in naps))
        out["ww_first"].append(ww[0])
        out["ww_last"].append(ww[-1])
        out["ww_mean"].append(float(np.mean(ww)))
        out["ww_min"].append(min(ww))
        out["ww_max"].append(max(ww))
        out["ww_rise"].append(ww[-1] - ww[0])  # last window minus first; should be >= 0
        out["bedtime"].append(night[0] % 24)
        out["wake"].append(morning % 24)
    return {k: float(np.mean(v)) for k, v in out.items() if v}
