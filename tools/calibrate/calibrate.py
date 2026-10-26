"""Fit the Settle sleep-pressure model to the targets in targets.py.

    python3 tools/calibrate/calibrate.py

Fits ONE age curve (8 global parameters, see model.AgeCurve) against all age
bands at once, so parameters change smoothly with age and nap transitions
emerge from the model instead of being set per band.

Writes tools/calibrate/out/curve.json, report.md, bands.png and sweep.png.
"""

import json
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import differential_evolution

sys.path.insert(0, str(Path(__file__).parent))
from model import AgeCurve, Params, metrics, pressure_trace, simulate  # noqa: E402
from targets import AGE_WK, BANDS, NAP_TYP  # noqa: E402

OUT = Path(__file__).parent / "out"
BIG = 1e3

BOUNDS = [
    (2.0, 40.0),  # tau_w_52
    (0.0, 2.0),  # k_w
    (0.5, 15.0),  # tau_s_52
    (-1.0, 1.5),  # k_s
    (0.2, 0.95),  # H0
    (0.02, 0.7),  # gap
    (0.0, 0.3),  # A_max
    (12.0, 22.0),  # phi
]


def band_loss(p: Params, consolidated, targets):
    if p.L0 <= 0.01 or p.H0 + p.A >= 0.99 or p.L0 - p.A <= 0.0:
        return BIG
    bouts = simulate(p)
    if bouts is None:
        return BIG
    m = metrics(bouts, consolidated=consolidated)
    if m is None:
        return BIG
    loss = 0.0
    for key, (lo, hi, w) in targets.items():
        v = m.get(key, np.nan)
        if not np.isfinite(v):
            return BIG
        scale = max(hi - lo, 0.5)
        if v < lo:
            loss += w * ((lo - v) / scale) ** 2
        elif v > hi:
            loss += w * ((v - hi) / scale) ** 2
        loss += 0.02 * w * ((v - (lo + hi) / 2) / scale) ** 2  # mild pull to centre
    if consolidated:
        if min(e - s for s, e in bouts[-15:]) < 0.33:
            loss += 2.0  # naps under 20 min every cycle = not a sensible schedule
        loss += day_to_day_penalty(bouts)
    return loss


def day_to_day_penalty(bouts, days=10, last=3):
    """A real routine repeats: penalise bedtime / wake drift across the last days."""
    nights = [(s, e) for s, e in bouts if e - s >= 5 and s >= (days - last - 1) * 24]
    if len(nights) < 2:
        return 2.0
    on = np.array([s % 24 for s, _ in nights])
    return float(np.std(on)) * 2


def replay_window(p: Params, nap_h: float, wake: float = 7.0):
    """Morning wake at `wake`, first nap when the window opens, nap lasts nap_h. Returns the next wake window."""
    from model import next_sleep
    s = float(p.L(wake))
    w1 = next_sleep(p, wake, s)
    if not np.isfinite(w1):
        return np.nan
    s = float(p.H(wake + w1)) * np.exp(-nap_h / p.tau_s)
    return next_sleep(p, wake + w1 + nap_h, s)


def replay_loss(p: Params, name, targets):
    if name not in NAP_TYP:
        return 0.0
    lo, hi, _ = targets["ww_mean"]
    w = replay_window(p, NAP_TYP[name])
    if not np.isfinite(w):
        return BIG
    scale = max(hi - lo, 0.5)
    return 3 * (max(0.8 * lo - w, 0, w - hi) / scale) ** 2


def curve_loss(x):
    c = AgeCurve(*x)
    total = 0.0
    for name, _, cons, _, t in BANDS:
        p = c.at(AGE_WK[name])
        if p.tau_s >= p.tau_w:
            total += 5 * (p.tau_s / p.tau_w)  # physiology: pressure clears faster than it builds
        total += band_loss(p, cons, t) + replay_loss(p, name, t)
    return total


def sweep(c: AgeCurve):
    """Weekly sweep 1..104 weeks: emergent nap count, windows, bedtime."""
    rows = []
    for wk in range(1, 105):
        p = c.at(wk)
        bouts = simulate(p)
        m = metrics(bouts, consolidated=wk >= 12) if bouts else None
        if m is None and bouts:
            m = metrics(bouts, consolidated=False)
        rows.append({"age_wk": wk, **(m or {}), **{f"p_{k}": v for k, v in p.as_dict().items()}})
    return rows


def main():
    OUT.mkdir(exist_ok=True)
    r = differential_evolution(curve_loss, BOUNDS, seed=3, popsize=25, maxiter=300, tol=1e-7,
                               polish=False, workers=-1, updating="deferred")
    c = AgeCurve(*r.x)
    print(f"total loss {r.fun:.3f}  " + " ".join(f"{k}={v:.3f}" for k, v in c.__dict__.items()))
    results = []
    for name, label, cons, _, targets in BANDS:
        p = c.at(AGE_WK[name])
        m = metrics(simulate(p), consolidated=cons)
        loss = band_loss(p, cons, targets) + replay_loss(p, name, targets)
        if name in NAP_TYP:
            m["replay_ww"] = replay_window(p, NAP_TYP[name])
        results.append({"band": name, "age": label, "loss": loss, "params": p.as_dict(), "metrics": m, "targets": targets})
        print(f"{name:8s} loss={loss:6.3f} " + " ".join(f"{k}={v:.2f}" for k, v in m.items()), flush=True)
    rows = sweep(c)
    (OUT / "curve.json").write_text(json.dumps({"curve": c.__dict__, "loss": float(r.fun), "bands": results, "sweep": rows}, indent=2))
    write_report(c, results, rows)
    plot_bands(results)
    plot_sweep(rows)


def fmt_h(h):
    return f"{int(h)}:{round((h % 1) * 60):02d}"


def write_report(c, results, rows):
    keys = ["ww_mean", "replay_ww", "ww_first", "ww_last", "naps", "bouts", "day_sleep", "night", "tst", "bedtime", "wake"]
    lines = ["# Calibration report", "", "## Age curve (global parameters)", "",
             "| param | value |", "|---|---|"]
    lines += [f"| {k} | {v:.3f} |" for k, v in c.__dict__.items()]
    lines += ["", "## Per band: parameters at band centre age", "",
              "| band | τw (h) | τs (h) | H0 | L0 | A | φ | loss |", "|---|---|---|---|---|---|---|---|"]
    for r in results:
        p = r["params"]
        cells = [f"{p['tau_w']:.2f}", f"{p['tau_s']:.2f}", f"{p['H0']:.3f}", f"{p['L0']:.3f}", f"{p['A']:.3f}", f"{p['phi']:.1f}"]
        lines.append(f"| {r['band']} | " + " | ".join(cells) + f" | {r['loss']:.2f} |")
    lines += ["", "## Simulated vs target", "", "Target range in brackets; ✗ = outside.", "",
              "| band | " + " | ".join(keys) + " |", "|---|" + "---|" * len(keys)]
    for r in results:
        cells = []
        for k in keys:
            v = r["metrics"].get(k)
            if v is None:
                cells.append("–")
                continue
            t = r["targets"].get(k)
            s = fmt_h(v) if k in ("bedtime", "wake") else f"{v:.2f}"
            if t:
                ok = t[0] - 1e-6 <= v <= t[1] + 1e-6
                s += f" [{t[0]}–{t[1]}]" + ("" if ok else " ✗")
            cells.append(s)
        lines.append(f"| {r['band']} | " + " | ".join(cells) + " |")
    lines += ["", "## Emergent nap transitions (weekly sweep)", ""]
    prev = None
    for row in rows:
        n = round(row["naps"]) if "naps" in row else None
        if n is not None and n != prev:
            lines.append(f"- from **{row['age_wk']} wk** (~{row['age_wk'] / 4.35:.1f} mo): {n} naps")
            prev = n
    (OUT / "report.md").write_text("\n".join(lines) + "\n")


def plot_bands(results):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(len(results), 1, figsize=(11, 2.1 * len(results)), sharex=True)
    for ax, r in zip(axes, results, strict=True):
        p = Params(**{k: r["params"][k] for k in ("tau_w", "tau_s", "H0", "gap", "A", "phi")})
        bouts = simulate(p)
        t_from, t_to = 8 * 24 + 4, 9 * 24 + 4
        ts, S = pressure_trace(p, bouts, t_from, t_to)
        x = ts - 8 * 24
        ax.plot(x, S, color="#3b6ea5", lw=1.6, label="S (pressure)")
        ax.plot(x, p.H(ts), color="#c0504d", lw=1, ls="--", label="H (fall asleep)")
        ax.plot(x, p.L(ts), color="#6a9f58", lw=1, ls="--", label="L (wake up)")
        for s, e in bouts:
            if e > t_from and s < t_to:
                ax.axvspan(max(s, t_from) - 8 * 24, min(e, t_to) - 8 * 24, color="#9aa7c7", alpha=0.3, lw=0)
        ax.set_ylim(0, 1)
        ax.set_ylabel(f"{r['band']}\n({r['age']})", rotation=0, ha="right", va="center")
        ax.grid(alpha=0.2)
    axes[0].legend(loc="upper right", fontsize=8, ncol=3)
    axes[-1].set_xticks(range(4, 29, 2))
    axes[-1].set_xticklabels([f"{h % 24:02d}:00" for h in range(4, 29, 2)])
    fig.suptitle("Settle sleep-pressure model: one simulated day per age (shaded = asleep)")
    fig.tight_layout()
    fig.savefig(OUT / "bands.png", dpi=110)


def plot_sweep(rows):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    wk = np.array([r["age_wk"] for r in rows])
    get = lambda k: np.array([r.get(k, np.nan) for r in rows])  # noqa: E731
    fig, ax = plt.subplots(3, 1, figsize=(10, 8), sharex=True)
    ax[0].plot(wk, get("naps"), color="#3b6ea5", label="naps/day")
    ax[0].plot(wk, get("bouts"), color="#999", ls=":", label="sleep bouts/day")
    ax[0].set_ylabel("count")
    ax[1].plot(wk, get("ww_first"), label="first wake window")
    ax[1].plot(wk, get("ww_mean"), label="mean")
    ax[1].plot(wk, get("ww_last"), label="last (before bed)")
    ax[1].set_ylabel("hours")
    ax[2].plot(wk, get("tst"), label="total sleep / 24h")
    ax[2].plot(wk, get("night"), label="night")
    ax[2].plot(wk, get("day_sleep"), label="day sleep")
    ax[2].set_ylabel("hours")
    ax[2].set_xlabel("age (weeks)")
    for a in ax:
        a.grid(alpha=0.2)
        a.legend(fontsize=8)
    fig.suptitle("Emergent schedule across 0–24 months (one smooth age curve)")
    fig.tight_layout()
    fig.savefig(OUT / "sweep.png", dpi=110)


if __name__ == "__main__":
    main()
