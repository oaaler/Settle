"""Export reference cases so the Swift engine can be checked against the Python model.

    python3 tools/calibrate/export_fixtures.py

Writes Packages/SettleCore/Tests/SettleCoreTests/Fixtures/reference.json.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from model import AgeCurve, next_sleep  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CURVE = json.loads((Path(__file__).parent / "out" / "curve.json").read_text())["curve"]
DEST = ROOT / "Packages/SettleCore/Tests/SettleCoreTests/Fixtures/reference.json"


def main():
    c = AgeCurve(**CURVE)
    cases = []
    for age_wk in (3, 9, 14, 21.7, 30.4, 43.5, 58.7, 84.8):
        p = c.at(age_wk)
        for clock in (7.0, 10.5, 14.0, 17.5):
            for s0 in (p.L(clock), p.L(clock) + 0.6 * p.gap):
                cases.append({
                    "age_weeks": age_wk,
                    "params": {"tauW": p.tau_w, "tauS": p.tau_s, "h0": p.H0, "gap": p.gap, "amplitude": p.A, "phiHour": p.phi},
                    "clock_hour": clock,
                    "s0": s0,
                    "hours_until_sleep": next_sleep(p, clock, s0),
                })
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(json.dumps({"curve": CURVE, "cases": cases}, indent=1))
    print(f"wrote {len(cases)} cases to {DEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
