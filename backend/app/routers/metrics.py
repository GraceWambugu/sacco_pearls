from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import require_admin
from ..models import FinancialMetric, Sacco
from ..schemas import MetricCreate, MetricOut, MetricUpdate

router = APIRouter(tags=["Financial metrics"])


@router.get("/saccos/{sacco_id}/metrics", response_model=list[MetricOut])
def list_metrics(
    sacco_id: int,
    from_year: Optional[int] = Query(None),
    to_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    """Trend data for one SACCO, oldest year first."""
    if not db.get(Sacco, sacco_id):
        raise HTTPException(404, "SACCO not found")
    stmt = select(FinancialMetric).where(FinancialMetric.sacco_id == sacco_id)
    if from_year is not None:
        stmt = stmt.where(FinancialMetric.data_year >= from_year)
    if to_year is not None:
        stmt = stmt.where(FinancialMetric.data_year <= to_year)
    return db.scalars(stmt.order_by(FinancialMetric.data_year)).all()


@router.post("/saccos/{sacco_id}/metrics", response_model=MetricOut,
             status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_admin)])
def create_metric(sacco_id: int, data: MetricCreate, db: Session = Depends(get_db)):
    if not db.get(Sacco, sacco_id):
        raise HTTPException(404, "SACCO not found")
    exists = db.scalar(select(FinancialMetric).where(
        FinancialMetric.sacco_id == sacco_id, FinancialMetric.data_year == data.data_year))
    if exists:
        raise HTTPException(409, f"Metrics for {data.data_year} already exist for this SACCO")
    metric = FinancialMetric(sacco_id=sacco_id, **data.model_dump())
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return metric


@router.put("/metrics/{metric_id}", response_model=MetricOut, dependencies=[Depends(require_admin)])
def update_metric(metric_id: int, data: MetricUpdate, db: Session = Depends(get_db)):
    metric = db.get(FinancialMetric, metric_id)
    if not metric:
        raise HTTPException(404, "Metric not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(metric, field, value)
    db.commit()
    db.refresh(metric)
    return metric


@router.delete("/metrics/{metric_id}", status_code=status.HTTP_204_NO_CONTENT,
               dependencies=[Depends(require_admin)])
def delete_metric(metric_id: int, db: Session = Depends(get_db)):
    metric = db.get(FinancialMetric, metric_id)
    if not metric:
        raise HTTPException(404, "Metric not found")
    db.delete(metric)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
