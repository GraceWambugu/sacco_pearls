"""Admin-only PDF upload and SASRA growth-indicator data import."""
import pandas as pd
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import require_admin
from ..etl import GROWTH_METRICS, extract_growth_table
from ..models import FinancialMetric, Report, Sacco, SaccoAlias
from ..utils import normalize_name

router = APIRouter(prefix="/ingest", tags=["Data ingestion"])

MAX_UPLOAD_BYTES = 100 * 1024 * 1024


@router.post("/growth", dependencies=[Depends(require_admin)])
async def ingest_growth(
    file: UploadFile = File(..., description="SASRA annual supervision report (PDF)"),
    pages: str = Form(..., description="Camelot page range for the growth appendix, e.g. 166-169"),
    report_year: int = Form(...),
    prior_year: int = Form(...),
    current_year: int = Form(...),
    db: Session = Depends(get_db),
):
    """Loads total assets, deposits, gross loans and total income.

    For older reports that list only one data year (e.g. the 2020 report),
    send the same value for prior_year and current_year.
    """
    if not (file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(400, "Please upload a PDF file")

    try:
        page_start = int(pages.split("-")[0])
        if page_start < 1:
            raise ValueError
    except ValueError:
        raise HTTPException(422, "Invalid page range") from None

    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(400, "File too large (100 MB limit)")

    try:
        df = extract_growth_table(raw, pages, prior_year, current_year)
    except Exception as exc:
        raise HTTPException(422, f"Extraction failed: {exc}") from exc

    if df.empty:
        raise HTTPException(
            422, "No rows were extracted. Check the page range points at the growth indicators table.")

    report = db.scalar(select(Report).where(Report.report_year == report_year))
    if not report:
        report = Report(report_year=report_year, source_file=file.filename, units="Kshs billions")
        db.add(report)
        db.flush()

    created_saccos = created_metrics = updated_metrics = 0

    for row in df.to_dict("records"):
        key = normalize_name(row["sacco_name"])
        alias = db.scalar(select(SaccoAlias).where(SaccoAlias.alias == key))
        if alias:
            sacco_id = alias.sacco_id
        else:
            existing = db.scalar(select(Sacco).where(Sacco.name == row["sacco_name"]))
            if existing:
                sacco_id = existing.id
            else:
                sacco = Sacco(name=row["sacco_name"])
                db.add(sacco)
                db.flush()
                sacco_id = sacco.id
                created_saccos += 1
            db.add(SaccoAlias(sacco_id=sacco_id, alias=key))
            db.flush()

        year = int(row["data_year"])
        metric = db.scalar(select(FinancialMetric).where(
            FinancialMetric.sacco_id == sacco_id, FinancialMetric.data_year == year))
        if metric:
            updated_metrics += 1
        else:
            metric = FinancialMetric(sacco_id=sacco_id, data_year=year)
            db.add(metric)
            created_metrics += 1

        for field in GROWTH_METRICS:
            value = row.get(field)
            if pd.notna(value):
                setattr(metric, field, float(value))
        # Keep provenance from the stability upload if this row already has it.
        if metric.report_id is None:
            metric.report_id = report.id
        if metric.source_page is None:
            metric.source_page = page_start

    db.commit()

    return {
        "saccos_created": created_saccos,
        "metrics_created": created_metrics,
        "metrics_updated": updated_metrics,
        "rows_extracted": len(df),
        "preview": df.head(5).to_dict("records"),
    }
