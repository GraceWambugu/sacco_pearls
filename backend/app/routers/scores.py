"""Public read endpoints that score SACCOs using the rules in app/scoring.py."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import scoring
from ..database import get_db
from ..models import FinancialMetric, Sacco

router = APIRouter(tags=["Scores"])


def _metric(db: Session, sacco_id: int, year: int):
    return db.scalar(select(FinancialMetric).where(
        FinancialMetric.sacco_id == sacco_id, FinancialMetric.data_year == year))


def _peer_median(db: Session, year: int):
    """Median income/assets (%) of every SACCO with data for that year."""
    rows = db.execute(select(FinancialMetric.total_income, FinancialMetric.total_assets)
                      .where(FinancialMetric.data_year == year)).all()
    return scoring.median_yield([scoring.yield_pct(income, assets) for income, assets in rows])


def _score(db: Session, sacco: Sacco, year: int, peer_median):
    metric = _metric(db, sacco.id, year)
    if metric is None:
        raise HTTPException(404, f"No figures for {sacco.name} in {year}")
    prior = _metric(db, sacco.id, year - 1)
    result = scoring.score_sacco(metric, prior, peer_median, scoring.INFLATION.get(year))
    return {"sacco": {"id": sacco.id, "name": sacco.name, "county": sacco.county}, **result}


@router.get("/saccos/{sacco_id}/score")
def get_score(
    sacco_id: int,
    year: Optional[int] = Query(None, description="Data year; defaults to the latest year available"),
    db: Session = Depends(get_db),
):
    """PEARLS-aligned score, rating and explanation for one SACCO."""
    sacco = db.get(Sacco, sacco_id)
    if sacco is None:
        raise HTTPException(404, "SACCO not found")
    if year is None:
        year = db.scalar(select(func.max(FinancialMetric.data_year))
                         .where(FinancialMetric.sacco_id == sacco_id))
        if year is None:
            raise HTTPException(404, f"No figures loaded for {sacco.name}")
    return _score(db, sacco, year, _peer_median(db, year))


@router.get("/compare")
def compare(
    ids: str = Query(..., description="2 or 3 different SACCO ids, comma-separated, e.g. 1,2,3"),
    year: Optional[int] = Query(None, description="Data year; defaults to the latest year all have"),
    db: Session = Depends(get_db),
):
    """Score up to three SACCOs side by side (matches the watchlist limit of 3)."""
    try:
        wanted = list(dict.fromkeys(int(part) for part in ids.split(",") if part.strip()))
    except ValueError:
        raise HTTPException(422, "ids must be whole numbers separated by commas") from None
    if not 2 <= len(wanted) <= 3:
        raise HTTPException(422, "Compare 2 or 3 different SACCOs")

    saccos = {s.id: s for s in db.scalars(select(Sacco).where(Sacco.id.in_(wanted))).all()}
    missing = [i for i in wanted if i not in saccos]
    if missing:
        raise HTTPException(404, f"SACCO id(s) not found: {missing}")

    if year is None:
        years_by_sacco = {i: set() for i in wanted}
        for sacco_id, data_year in db.execute(
                select(FinancialMetric.sacco_id, FinancialMetric.data_year)
                .where(FinancialMetric.sacco_id.in_(wanted))).all():
            years_by_sacco[sacco_id].add(data_year)
        common = set.intersection(*years_by_sacco.values())
        if not common:
            raise HTTPException(404, "These SACCOs have no data year in common")
        year = max(common)

    peer = _peer_median(db, year)
    results = [_score(db, saccos[i], year, peer) for i in wanted]
    ranking = [r["sacco"]["id"] for r in sorted(
        results, key=lambda r: (r["composite"] is None, -(r["composite"] or 0)))]
    return {"year": year, "results": results, "ranking": ranking}


@router.get("/rankings")
def rankings(
    year: Optional[int] = Query(None, description="Data year; defaults to the latest year loaded"),
    limit: int = Query(10, ge=1, le=200, description="How many to return; 200 covers every DT-SACCO"),
    db: Session = Depends(get_db),
):
    """Top-scoring SACCOs for one year, best first, with three headline figures each.
    SACCOs that cannot be rated are left out."""
    if year is None:
        year = db.scalar(select(func.max(FinancialMetric.data_year)))
        if year is None:
            raise HTTPException(404, "No figures loaded yet")

    # Two queries (this year and last year) instead of two per SACCO, so ranking ~180 SACCOs stays fast.
    rows = db.execute(select(FinancialMetric, Sacco)
                      .join(Sacco, Sacco.id == FinancialMetric.sacco_id)
                      .where(FinancialMetric.data_year == year, Sacco.is_archived.is_(False))).all()
    if not rows:
        raise HTTPException(404, f"No figures for {year}")
    prior_by_sacco = {m.sacco_id: m for m in db.scalars(
        select(FinancialMetric).where(FinancialMetric.data_year == year - 1)).all()}

    peer = _peer_median(db, year)
    inflation = scoring.INFLATION.get(year)
    ranked = []
    for metric, sacco in rows:
        result = scoring.score_sacco(metric, prior_by_sacco.get(sacco.id), peer, inflation)
        if result["composite"] is None:
            continue
        ranked.append({"sacco": {"id": sacco.id, "name": sacco.name, "county": sacco.county},
                       "composite": result["composite"], "rating": result["rating"],
                       "dimensions_scored": result["dimensions_scored"],
                       # Headline figures for the app's cards, straight from SASRA's tables.
                       "year": year, "total_assets": metric.total_assets, "npl_ratio": metric.npl_ratio,
                       "cca": metric.cca})
    # Highest composite first; equal scores are listed by name so the order is stable.
    ranked.sort(key=lambda r: (-r["composite"], r["sacco"]["name"]))
    return ranked[:limit]


@router.get("/saccos/{sacco_id}/trend")
def trend(sacco_id: int, db: Session = Depends(get_db)):
    """One SACCO's score and key figures for every year that has data, oldest first."""
    sacco = db.get(Sacco, sacco_id)
    if sacco is None:
        raise HTTPException(404, "SACCO not found")

    metrics = db.scalars(select(FinancialMetric).where(FinancialMetric.sacco_id == sacco_id)
                         .order_by(FinancialMetric.data_year)).all()
    by_year = {m.data_year: m for m in metrics}
    points = []
    for m in metrics:
        # Each year is scored exactly as the Profile screen scores it: same peers, same prior year.
        result = scoring.score_sacco(m, by_year.get(m.data_year - 1), _peer_median(db, m.data_year),
                                     scoring.INFLATION.get(m.data_year))
        points.append({
            "year": m.data_year,
            "composite": result["composite"],
            "rating": result["rating"],
            "dimension_scores": {code: result["dimensions"][code]["score"] for code in ("E", "A", "R", "S")},
            "total_assets": m.total_assets,
            "total_deposits": m.total_deposits,
            "gross_loans": m.gross_loans,
            "cca": m.cca,
            "npl_ratio": m.npl_ratio,
            "data_stale": m.data_stale,
        })
    return points
