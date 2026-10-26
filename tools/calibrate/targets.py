"""Calibration targets per age band (0-24 months).

Each target is (low, high, weight). Hours unless noted.

Provenance (see docs/research/sleep-science.md):
  tst        AASM 2016 consensus for 4-24 mo (12-16 h, 11-14 h). Under 4 mo AASM gives none;
             13.5-16.5 h is a broad clinical-guidance band (unverified), so weight is low.
  ww_*       SPEC 3.1 wake-window ranges. These are popular heuristics, NOT studied evidence.
  naps       SPEC 3.1; matches Galland 2012 trend (naps fall up to age 2).
  night      10.5-12 h in bed incl. brief wakings: common guidance, unverified, lower weight.
  bedtime/wake  social targets, not biology; low weight.
  ww_min/max  every window of the day stays near the band's range (0.8x low .. 1.25x high).
  ww_rise     last window >= first window: windows lengthen through the day (common guidance).
"""


def _shape(lo, hi):
    return {"ww_min": (0.8 * lo, hi, 2), "ww_max": (lo, 1.25 * hi, 2), "ww_rise": (0.0, 0.6 * hi, 2)}

# Typical single-nap length (h) per band, common guidance (unverified). Used for the "replay"
# check: after a nap of this length, the next wake window must still land in the band's range.
# This mirrors how the app is used: parents decide nap length, the model predicts what follows.
NAP_TYP = {"3-4mo": 1.0, "4-6mo": 1.0, "6-8mo": 1.25, "8-12mo": 1.25, "12-15mo": 1.75, "15-24mo": 2.0}

AGE_WK = {"0-6wk": 3, "6-12wk": 9, "3-4mo": 14, "4-6mo": 21.7, "6-8mo": 30.4, "8-12mo": 43.5, "12-15mo": 58.7, "15-24mo": 84.8}

BANDS = [
    # name, age label, consolidated night?, max circadian amplitude (per-band fit only), targets
    ("0-6wk", "3 wk", False, 0.0, {
        "ww_mean": (0.75, 1.0, 3), "bouts": (5, 7, 2), "tst": (13.5, 16.5, 0.5),
    }),
    ("6-12wk", "9 wk", False, 0.05, {
        "ww_mean": (1.0, 1.5, 3), "bouts": (5, 6, 2), "tst": (13.5, 16.5, 0.5),
    }),
    ("3-4mo", "14 wk", True, 0.3, {
        "ww_mean": (1.25, 2.0, 3), **_shape(1.25, 2.0), "naps": (4, 4, 2), "tst": (12, 16, 1),
        "night": (10, 12, 1), "bedtime": (18.5, 20.5, 0.5), "wake": (6, 7.5, 0.5),
    }),
    ("4-6mo", "5 mo", True, 0.3, {
        "ww_mean": (1.75, 2.5, 3), **_shape(1.75, 2.5), "naps": (3, 3, 2), "tst": (12, 16, 1), "day_sleep": (3, 4, 1),
        "night": (10.5, 12, 1), "bedtime": (18.5, 20, 0.5), "wake": (6, 7.5, 0.5),
    }),
    ("6-8mo", "7 mo", True, 0.3, {
        "ww_mean": (2.25, 3.0, 3), **_shape(2.25, 3.0), "naps": (2, 3, 2), "tst": (12, 16, 1), "day_sleep": (2.5, 3.5, 1),
        "night": (10.5, 12, 1), "bedtime": (18.5, 20, 0.5), "wake": (6, 7.5, 0.5),
    }),
    ("8-12mo", "10 mo", True, 0.3, {
        "ww_mean": (2.75, 3.75, 3), **_shape(2.75, 3.75), "naps": (2, 2, 2), "tst": (12, 16, 1), "day_sleep": (2, 3, 1),
        "night": (10.5, 12, 1), "bedtime": (18.5, 20, 0.5), "wake": (6, 7.5, 0.5),
    }),
    ("12-15mo", "13.5 mo", True, 0.3, {
        "ww_mean": (3.5, 4.5, 3), **_shape(3.5, 4.5), "naps": (1, 2, 2), "tst": (11, 14, 1), "day_sleep": (2, 3, 1),
        "night": (10.5, 12, 1), "bedtime": (18.5, 20, 0.5), "wake": (6, 7.5, 0.5),
    }),
    ("15-24mo", "19.5 mo", True, 0.3, {
        "ww_mean": (4.5, 6.0, 3), **_shape(4.5, 6.0), "naps": (1, 1, 2), "tst": (11, 14, 1), "day_sleep": (1.5, 2.5, 1),
        "night": (10.5, 12, 1), "bedtime": (18.5, 20.5, 0.5), "wake": (6, 7.5, 0.5),
    }),
]
