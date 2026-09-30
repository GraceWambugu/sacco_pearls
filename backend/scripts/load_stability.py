"""Load the cleaned SASRA stability CSV into PostgreSQL.
Run from the backend folder, e.g.:
  python -m scripts.load_stability ../data/processed/stability_2024_report.csv --report-year 2024 --source sasra_2024.pdf --page 174
"""
import argparse

import pandas as pd
from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models import FinancialMetric, Report, Sacco, SaccoAlias
from app.utils import normalize_name

FIELDS = ["cca", "ccd", "ica", "ext_borrowing", "npl_ratio"]


def load(csv_path: str, report_year: int, source: str, page: int | None):
    df = pd.read_csv(csv_path)
    Base.metadata.create_all(bind=engine)
    created_saccos = created_metrics = updated_metrics = 0

    with SessionLocal() as db:
        report = db.scalar(select(Report).where(Report.report_year == report_year))
        if not report:
            report = Report(report_year=report_year, source_file=source, units="Kshs billions")
            db.add(report)
            db.flush()

        for row in df.to_dict("records"):
            key = normalize_name(row["sacco_name"])
            alias = db.scalar(select(SaccoAlias).where(SaccoAlias.alias == key))
            if alias:
                sacco_id = alias.sacco_id
            else:
                # Also check by exact name, in case the same SACCO text appears
                # twice in the source PDF table (a known Camelot page-break artifact)
                # without an alias having been recorded for it yet.
                existing = db.scalar(select(Sacco).where(Sacco.name == row["sacco_name"]))
                if existing:
                    sacco_id = existing.id
                else:
                    sacco = Sacco(name=row["sacco_name"])
                    db.add(sacco)
                    db.flush()
                    sacco_id = sacco.id
                    created_saccos += 1
                if not db.scalar(select(SaccoAlias).where(SaccoAlias.alias == key)):
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

            for f in FIELDS:
                if pd.notna(row[f]):
                    setattr(metric, f, float(row[f]))
            metric.data_stale = bool(row.get("footnote_star", False))
            metric.report_id = report.id
            metric.source_page = page

        db.commit()
    print(f"SACCOs created: {created_saccos} | metrics created: {created_metrics} | metrics updated: {updated_metrics}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--report-year", type=int, required=True)
    ap.add_argument("--source", required=True)
    ap.add_argument("--page", type=int, default=None)
    a = ap.parse_args()
    load(a.csv, a.report_year, a.source, a.page)
