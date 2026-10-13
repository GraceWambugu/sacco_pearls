"""Unit tests for the scoring rules in app/scoring.py. No database needed.

Run:  pytest tests/test_scoring.py -v
"""
import math
from types import SimpleNamespace as NS

from app import scoring as sc


def metric(**overrides):
    """A healthy SACCO-year; tests change one thing at a time."""
    base = dict(data_year=2024, total_assets=10.0, total_deposits=7.0, gross_loans=6.0,
                total_income=1.5, cca=15.0, ccd=20.0, ica=12.0, ext_borrowing=5.0,
                npl_ratio=3.0, data_stale=False)
    base.update(overrides)
    return NS(**base)


PRIOR = metric(data_year=2023, total_assets=9.0, total_deposits=6.3, gross_loans=5.4)  # 2024 growth ~11%
MEDIAN = 15.0     # income/assets of the test SACCO is 1.5/10 = 15%
INFL = 4.5


def score(m=None, prior=PRIOR, median=MEDIAN, inflation=INFL):
    return sc.score_sacco(m or metric(), prior, median, inflation)


# ---------------------------- indicator boundaries ----------------------------
def test_capital_ratio_boundaries():
    assert sc.band_higher_is_better(9.99, 10) == "Red"
    assert sc.band_higher_is_better(10, 10) == "Amber"        # exactly the minimum is compliant
    assert sc.band_higher_is_better(12.49, 10) == "Amber"
    assert sc.band_higher_is_better(12.5, 10) == "Green"      # 25% above the minimum
    assert sc.band_higher_is_better(-5, 10) == "Red"
    assert sc.band_higher_is_better(None, 10) is None
    assert sc.band_higher_is_better(float("nan"), 10) is None


def test_external_borrowing_boundaries():
    assert sc.band_lower_is_better(25.01, 25) == "Red"
    assert sc.band_lower_is_better(25, 25) == "Amber"         # exactly the maximum is compliant
    assert sc.band_lower_is_better(18.76, 25) == "Amber"
    assert sc.band_lower_is_better(18.75, 25) == "Green"      # 25% below the maximum
    assert sc.band_lower_is_better(None, 25) is None


def test_npl_boundaries():
    assert sc.band_npl(5.0) == "Green"
    assert sc.band_npl(5.01) == "Amber"
    assert sc.band_npl(10.0) == "Amber"
    assert sc.band_npl(10.01) == "Red"
    assert sc.band_npl(None) is None


def test_growth_boundaries():
    assert sc.band_growth(-0.1, 4.5) == "Red"
    assert sc.band_growth(0, 4.5) == "Amber"
    assert sc.band_growth(4.49, 4.5) == "Amber"
    assert sc.band_growth(4.5, 4.5) == "Green"                # real growth: at or above inflation
    assert sc.band_growth(5, None) is None


def test_yield_bands():
    assert sc.band_yield(15, 15) == "Green"
    assert sc.band_yield(11.25, 15) == "Amber"
    assert sc.band_yield(11.24, 15) == "Red"
    assert sc.band_yield(10, None) is None


def test_rating_cutoffs():
    assert sc._rating(75.0) == "Green"
    assert sc._rating(74.9) == "Amber"
    assert sc._rating(50.0) == "Amber"
    assert sc._rating(49.9) == "Red"


def test_helpers():
    assert math.isclose(sc.growth_pct(110, 100), 10.0)
    assert sc.growth_pct(5, 0) is None                        # no growth rate from a zero base
    assert sc.growth_pct(None, 5) is None
    assert math.isclose(sc.yield_pct(1.5, 10), 15.0)
    assert sc.yield_pct(1, 0) is None
    assert sc.median_yield([1, None, 3]) == 2
    assert sc.median_yield([None]) is None


# ------------------------------- whole-SACCO scoring -------------------------------
def test_healthy_sacco_is_green_with_all_four_dimensions():
    r = score()
    assert r["rating"] == "Green" and r["composite"] == 100.0
    assert r["dimensions_scored"] == 4 and r["dimensions_total"] == 6
    assert r["overrides"] == [] and r["flags"] == []
    assert math.isclose(sum(r["weights_used"].values()), 1.0, abs_tol=0.001)


def test_all_six_dimensions_are_reported_in_order_with_reasons():
    r = score()
    assert list(r["dimensions"]) == ["P", "E", "A", "R", "L", "S"]
    assert r["dimensions"]["P"]["scored"] is False and r["dimensions"]["P"]["reason"]
    assert r["dimensions"]["L"]["scored"] is False and r["dimensions"]["L"]["reason"]
    assert r["dimensions"]["E"]["scored"] is True and len(r["dimensions"]["E"]["indicators"]) == 4


def test_missing_prior_year_drops_growth_and_rescales_weights():
    r = score(metric(npl_ratio=8.0), prior=None)             # E Green, A Amber, R Green, S not scored
    assert r["dimensions_scored"] == 3 and "limited" in r["flags"]
    assert "S" not in r["weights_used"]
    assert math.isclose(sum(r["weights_used"].values()), 1.0, abs_tol=0.001)
    assert 81.2 <= r["composite"] <= 81.3                     # (40 + 15 + 10) / 0.8 = 81.25
    assert r["dimensions"]["S"]["scored"] is False and "prior-year" in r["dimensions"]["S"]["reason"]


def test_no_inflation_figure_drops_growth():
    r = score(inflation=None)
    assert r["dimensions"]["S"]["scored"] is False and "inflation" in r["dimensions"]["S"]["reason"]


def test_negative_core_capital_forces_red():
    r = score(metric(cca=-5.0))
    assert r["rating"] == "Red"
    assert any("core capital" in o for o in r["overrides"])


def test_regulatory_breach_caps_green_at_amber():
    r = score(metric(ext_borrowing=30.0))                     # composite 90 would be Green
    assert r["composite"] >= 75 and r["rating"] == "Amber"
    assert any("Capped" in o for o in r["overrides"])


def test_critical_npl_forces_red_and_can_be_switched_off():
    r = score(metric(npl_ratio=40.0))                         # composite 70 would be Amber
    assert r["rating"] == "Red" and any("non-performing" in o for o in r["overrides"])
    saved = sc.NPL_CRITICAL_ABOVE
    try:
        sc.NPL_CRITICAL_ABOVE = None
        assert score(metric(npl_ratio=40.0))["rating"] == "Amber"
    finally:
        sc.NPL_CRITICAL_ABOVE = saved


def test_flags():
    assert "stale" in score(metric(data_stale=True))["flags"]
    assert "anomaly" in score(metric(total_assets=1.0, gross_loans=5.0))["flags"]   # assets below loans


def test_missing_values_do_not_crash():
    r = score(metric(cca=None, npl_ratio=None, total_income=None))
    assert r["rating"] in ("Green", "Amber", "Red")
    assert r["dimensions"]["A"]["scored"] is False


# --------------------- real SACCOs, hand-checked against the design ---------------------
STIMA_2023 = metric(data_year=2023, total_assets=59.15, total_deposits=43.13, gross_loans=49.4, total_income=8.95,
                    cca=17.45, ccd=23.93, ica=11.44, ext_borrowing=0.8, npl_ratio=3.66)
STIMA_2024 = metric(total_assets=66.51, total_deposits=46.69, gross_loans=54.89, total_income=10.26,
                    cca=19.22, ccd=27.38, ica=12.55, ext_borrowing=1.14, npl_ratio=6.53)
MWALIMU_2023 = metric(data_year=2023, total_assets=66.43, total_deposits=49.33, gross_loans=45.78, total_income=8.38,
                      cca=11.28, ccd=15.2, ica=7.7, ext_borrowing=4.68, npl_ratio=4.64)
MWALIMU_2024 = metric(total_assets=68.89, total_deposits=52.19, gross_loans=47.99, total_income=9.32,
                      cca=14.01, ccd=18.49, ica=9.96, ext_borrowing=1.79, npl_ratio=8.26)
PEER_MEDIAN_2024 = 15.19      # median income/assets of the 177 DT-SACCOs in 2024


def test_stima_2024_is_green():
    r = sc.score_sacco(STIMA_2024, STIMA_2023, PEER_MEDIAN_2024, 4.5)
    assert r["composite"] == 85.0 and r["rating"] == "Green"
    assert [r["dimensions"][k]["score"] for k in "EASR"] == [100.0, 50.0, 100.0, 100.0]


def test_mwalimu_2024_is_amber_because_ica_is_just_under_ten():
    r = sc.score_sacco(MWALIMU_2024, MWALIMU_2023, PEER_MEDIAN_2024, 4.5)
    ica = [i for i in r["dimensions"]["E"]["indicators"] if i["key"] == "ica"][0]
    assert ica["band"] == "Amber"                              # 9.96% is just under the 10% Green line
    assert r["composite"] == 71.7 and r["rating"] == "Amber"
