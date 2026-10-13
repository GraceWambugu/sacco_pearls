"""Rules-based, PEARLS-aligned scoring of DT-SACCOs.

Pure functions only: no database or web code, so every rule can be unit-tested.
Design, sources and the reasoning behind each threshold: docs/scoring_design.md.
Every design choice is a constant in the CONFIG block, so it can be changed in
one place.

This is a rules engine (fixed thresholds), not machine learning.
"""
import math
from statistics import median
from typing import Any, Optional

# ============================== CONFIG ==============================
MARGIN = 0.25               # Green = at least 25% better than the regulatory limit

# These ratios are read from the SASRA stability appendix as percentages.
# Prescribed standards printed in the header of the SASRA stability appendix
SASRA_CCA_MIN = 10.0        # core capital / total assets, minimum %
SASRA_CCD_MIN = 8.0         # core capital / total deposits, minimum %
SASRA_ICA_MIN = 8.0         # institutional capital / total assets, minimum %
SASRA_EXT_MAX = 25.0        # external borrowing / total assets, maximum %

NPL_GREEN_MAX = 5.0         # WOCCU PEARLS: no more than 5% delinquency
NPL_RED_ABOVE = 10.0        # design choice
NPL_CRITICAL_ABOVE = 25.0   # design choice: above this the rating is forced to Red (None disables)

YIELD_AMBER_FRACTION = 0.75  # design choice: income/assets compared with the peer median

# Annual average CPI inflation, %, KNBS (published by the Central Bank of Kenya)
INFLATION = {2023: 7.67, 2024: 4.50}

# Dimension weights; available dimensions are re-normalized to total 100% below.
WEIGHTS = {"E": 0.40, "A": 0.30, "S": 0.20, "R": 0.10}
# Indicator bands become points, then the composite becomes a final color.
POINTS = {"Green": 100, "Amber": 50, "Red": 0}
GREEN_FROM = 75.0
AMBER_FROM = 50.0

DIMENSIONS = [  # fixed display order
    ("P", "Protection"),
    ("E", "Effective financial structure"),
    ("A", "Asset quality"),
    ("R", "Rates of return and cost"),
    ("L", "Liquidity"),
    ("S", "Signs of growth"),
]
NEVER_SCORED = {
    "P": "Loan-loss provisions are not published per SACCO in the SASRA reports",
    "L": "A per-SACCO liquidity ratio is not published in the 2023 and 2024 SASRA reports",
}
# ====================================================================


def _num(x: Any) -> Optional[float]:
    """Return a float, or None for missing / NaN values."""
    if x is None:
        return None
    try:
        v = float(x)
    except (TypeError, ValueError):
        return None
    return None if math.isnan(v) else v


# ---------------------------- indicator bands ----------------------------
def band_higher_is_better(value, minimum, margin=MARGIN):
    """Ratios with a regulatory minimum: below it Red; within `margin` above it Amber; else Green."""
    v = _num(value)
    if v is None:
        return None
    if v < minimum:
        return "Red"
    if v < minimum * (1 + margin):
        return "Amber"
    return "Green"


def band_lower_is_better(value, maximum, margin=MARGIN):
    """Ratios with a regulatory maximum: above it Red; within `margin` below it Amber; else Green."""
    v = _num(value)
    if v is None:
        return None
    if v > maximum:
        return "Red"
    if v > maximum * (1 - margin):
        return "Amber"
    return "Green"


def band_npl(value):
    v = _num(value)
    if v is None:
        return None
    if v <= NPL_GREEN_MAX:
        return "Green"
    if v <= NPL_RED_ABOVE:
        return "Amber"
    return "Red"


def band_growth(growth_pct, inflation_pct):
    """Real positive growth (at or above inflation) Green; 0 to inflation Amber; shrinking Red."""
    g = _num(growth_pct)
    if g is None or inflation_pct is None:
        return None
    if g >= inflation_pct:
        return "Green"
    if g >= 0:
        return "Amber"
    return "Red"


def band_yield(yield_value, peer_median):
    y = _num(yield_value)
    if y is None or peer_median is None:
        return None
    if y >= peer_median:
        return "Green"
    if y >= YIELD_AMBER_FRACTION * peer_median:
        return "Amber"
    return "Red"


# ------------------------------ derived values ------------------------------
def growth_pct(current, previous) -> Optional[float]:
    """Calculate year-over-year percent change; missing/nonpositive prior values are unscored."""
    c, p = _num(current), _num(previous)
    if c is None or p is None or p <= 0:
        return None
    return (c / p - 1) * 100


def yield_pct(income, assets) -> Optional[float]:
    """Calculate income as a percentage of assets for peer comparison."""
    i, a = _num(income), _num(assets)
    if i is None or a is None or a <= 0:
        return None
    return i / a * 100


def median_yield(yields) -> Optional[float]:
    vals = [y for y in yields if y is not None]
    return median(vals) if vals else None


# --------------------------------- scoring ---------------------------------
def _indicator(key, label, value, band, rule, unit="%"):
    return {"key": key, "label": label, "value": _num(value), "unit": unit,
            "band": band, "points": POINTS.get(band), "rule": rule}


def _dimension(code, name, indicators):
    """Average scored indicators; missing indicators do not count as zero."""
    scored = [i for i in indicators if i["band"] is not None]
    score = sum(i["points"] for i in scored) / len(scored) if scored else None
    return {"code": code, "name": name, "scored": score is not None,
            "score": None if score is None else round(score, 1), "_raw": score,
            "indicators": indicators}


def _rating(composite):
    """Convert the weighted composite into Green (75+), Amber (50-74.9), or Red (<50)."""
    if composite >= GREEN_FROM:
        return "Green"
    if composite >= AMBER_FROM:
        return "Amber"
    return "Red"


def score_sacco(metric, prior, peer_median, inflation):
    """Score one SACCO-year.

    metric:       row for the year being scored (any object with the FinancialMetric attributes)
    prior:        row for the previous year, or None
    peer_median:  median income/assets (%) of all SACCOs in that year, or None
    inflation:    annual average inflation (%) for that year, or None
    """
    m = metric
    # E: capital adequacy and borrowing risk; A: loan quality (NPLs).
    e_inds = [
        _indicator("cca", "Core capital / total assets", m.cca,
                   band_higher_is_better(m.cca, SASRA_CCA_MIN),
                   f"SASRA minimum {SASRA_CCA_MIN:g}%; Green from {SASRA_CCA_MIN * (1 + MARGIN):g}%"),
        _indicator("ccd", "Core capital / total deposits", m.ccd,
                   band_higher_is_better(m.ccd, SASRA_CCD_MIN),
                   f"SASRA minimum {SASRA_CCD_MIN:g}%; Green from {SASRA_CCD_MIN * (1 + MARGIN):g}%"),
        _indicator("ica", "Institutional capital / total assets", m.ica,
                   band_higher_is_better(m.ica, SASRA_ICA_MIN),
                   f"SASRA minimum {SASRA_ICA_MIN:g}%; Green from {SASRA_ICA_MIN * (1 + MARGIN):g}%"),
        _indicator("ext_borrowing", "External borrowing / total assets", m.ext_borrowing,
                   band_lower_is_better(m.ext_borrowing, SASRA_EXT_MAX),
                   f"SASRA maximum {SASRA_EXT_MAX:g}%; Green up to {SASRA_EXT_MAX * (1 - MARGIN):g}%"),
    ]
    a_inds = [
        _indicator("npl_ratio", "Non-performing loans ratio", m.npl_ratio, band_npl(m.npl_ratio),
                   f"WOCCU: at most {NPL_GREEN_MAX:g}% is Green; above {NPL_RED_ABOVE:g}% is Red"),
    ]

    # R is an income/assets proxy compared with peers; S measures growth against inflation.
    own_yield = yield_pct(m.total_income, m.total_assets)
    r_inds = [
        _indicator("income_yield", "Total income / total assets (proxy)", own_yield,
                   band_yield(own_yield, peer_median),
                   "Compared with the median of all DT-SACCOs that year" +
                   ("" if peer_median is None else f" ({peer_median:.2f}%)")),
    ]

    s_inds = []
    if prior is not None and inflation is not None:
        for key, label, attr in (("asset_growth", "Total assets growth", "total_assets"),
                                 ("deposit_growth", "Deposits growth", "total_deposits"),
                                 ("loan_growth", "Gross loans growth", "gross_loans")):
            g = growth_pct(getattr(m, attr), getattr(prior, attr))
            s_inds.append(_indicator(key, label, g, band_growth(g, inflation),
                                     f"Green at or above inflation ({inflation:g}%); Amber 0% to inflation; Red if shrinking"))

    dims = {
        "E": _dimension("E", dict(DIMENSIONS)["E"], e_inds),
        "A": _dimension("A", dict(DIMENSIONS)["A"], a_inds),
        "R": _dimension("R", dict(DIMENSIONS)["R"], r_inds),
        "S": _dimension("S", dict(DIMENSIONS)["S"], s_inds),
    }
    scored = {k: d["_raw"] for k, d in dims.items() if d["scored"]}
    if not scored:
        return {"year": getattr(m, "data_year", None), "composite": None, "rating": None,
                "dimensions": _public_dimensions(dims, prior, inflation), "dimensions_scored": 0,
                "dimensions_total": len(DIMENSIONS), "weights_used": {}, "overrides": [], "flags": ["limited"]}

    # Missing dimensions are excluded, then the remaining weights are scaled to 100%.
    total_w = sum(WEIGHTS[k] for k in scored)
    weights_used = {k: round(WEIGHTS[k] / total_w, 4) for k in scored}
    composite = round(sum(WEIGHTS[k] * v for k, v in scored.items()) / total_w, 1)
    rating = _rating(composite)

    # Risk guardrails stop a strong average from hiding serious capital or NPL problems.
    overrides = []
    if rating == "Green" and any(i["band"] == "Red" for i in e_inds):
        rating = "Amber"
        overrides.append("Capped at Amber: a SASRA regulatory minimum or maximum is breached")
    cca = _num(m.cca)
    if cca is not None and cca < 0 and rating != "Red":
        rating = "Red"
        overrides.append("Red: core capital is negative")
    npl = _num(m.npl_ratio)
    if NPL_CRITICAL_ABOVE is not None and npl is not None and npl > NPL_CRITICAL_ABOVE and rating != "Red":
        rating = "Red"
        overrides.append(f"Red: non-performing loans exceed {NPL_CRITICAL_ABOVE:g}% of the loan book")

    flags = []
    if getattr(m, "data_stale", False):
        flags.append("stale")       # SASRA marked the row with an asterisk: figures may be carried forward
    ta, gl = _num(m.total_assets), _num(m.gross_loans)
    if ta is not None and gl is not None and ta < gl:
        flags.append("anomaly")     # assets below loans is impossible: the source table looks wrong
    if len(scored) < 4:
        flags.append("limited")

    return {
        "year": getattr(m, "data_year", None),
        "composite": composite,
        "rating": rating,
        "dimensions": _public_dimensions(dims, prior, inflation),
        "dimensions_scored": len(scored),
        "dimensions_total": len(DIMENSIONS),
        "weights_used": weights_used,
        "overrides": overrides,
        "flags": flags,
    }


def _public_dimensions(dims, prior, inflation):
    """All six PEARLS dimensions in order, with a reason for every one that is not scored."""
    out = {}
    for code, name in DIMENSIONS:
        if code in NEVER_SCORED:
            out[code] = {"code": code, "name": name, "scored": False, "score": None,
                         "reason": NEVER_SCORED[code], "indicators": []}
            continue
        d = {k: v for k, v in dims[code].items() if k != "_raw"}
        if not d["scored"]:
            if code == "S":
                d["reason"] = ("No prior-year figures for this SACCO" if prior is None
                               else "No inflation figure configured for this year")
            else:
                d["reason"] = "Required figures are missing"
        out[code] = d
    return out
