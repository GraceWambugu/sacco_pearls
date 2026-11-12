"""Load the older SASRA reports (2020, 2021, 2022) without touching validated figures.

Run from backend (dry run first, it changes nothing):
    python -m scripts.load_older_reports
    python -m scripts.load_older_reports --apply

Rules, so the 2022-2024 figures already checked against the PDFs stay as they are:
  - a SACCO-year that is not in the database yet is inserted;
  - a SACCO-year that exists only has EMPTY fields filled (e.g. the liquidity
    ratio, which only the 2022 report publishes); nothing is overwritten;
  - wherever two reports print the same figure, the two values are compared and
    the result goes to docs/validation_older_reports.csv as evidence.
"""
import argparse
import csv
import difflib
from pathlib import Path

from sqlalchemy import select

from app.database import SessionLocal
from app.etl import GROWTH_METRICS, METRICS_WITH_LIQUIDITY, extract_growth_table, extract_stability_table
from app.models import FinancialMetric, Report, Sacco, SaccoAlias
from app.utils import normalize_name

RAW = Path(__file__).resolve().parents[2] / "data" / "raw"
LOG = Path(__file__).resolve().parents[2] / "docs" / "validation_older_reports.csv"

# (pdf, report year, appendix, pages, first data year, second data year)
# Page numbers come from each report's table of contents (Appendix II/III).
SOURCES = [
    ("sasra_2022.pdf", 2022, "stability", "131-134", 2021, 2022),
    ("sasra_2022.pdf", 2022, "growth", "127-130", 2021, 2022),
    ("sasra_2021.pdf", 2021, "growth", "84-87", 2021, 2021),   # single-year table
    ("sasra_2020.pdf", 2020, "growth", "85-89", 2020, 2020),   # single-year table
]
TOLERANCE = 0.005  # figures are printed to 2 decimals

# Spellings in the 2020-2022 reports that are the same SACCO as a 2022-2024 name.
# Checked by hand against the reports; review this list before running --apply.
SAME_SACCO = {
    "NGARISHA": "NG'ARISHA",
    "TRANS-ELITE": "TRANS-ELITE COUNTY",
    "AGROCHEM": "AGRO CHEM",
    "AINABKOI": "AINABKOI FARMERS",
    "NEW FORTIS": "NEWFORTIS",
    "KITUI TECHERS": "KITUI TEACHERS",            # typo in the report
    "KEYSTONE (FORMERLY KITE)": "KEYSTONE DT.",
    "KITE": "KEYSTONE DT.",                       # renamed; the reports say "formerly Kite"
    "VISIONPOINT": "VISION POINT",
    "KOLENGE": "KOLENGE TEA",
    "KENYA POLICE": "KENYA NATIONAL POLICE DT.",
    "METROPOLITAN": "METROPOLITAN NATIONAL",
    "SHIRIKA DTS": "SHIRIKA DT.",
    "EGERTON": "EGERTON UNIVERSITY",
    "LAMU": "LAMU TEACHERS",
    "MOMBASA PORTS": "MOMBASA PORT",             # two spellings of one SACCO, both pre-2022
}


def _sacco_for(db, name, new_names):
    """Find the SACCO by its normalised name (aliases), else create it."""
    key = normalize_name(name)
    alias = db.scalar(select(SaccoAlias).where(SaccoAlias.alias == key))
    if alias:
        return alias.sacco_id
    existing = db.scalar(select(Sacco).where(Sacco.name == SAME_SACCO.get(name, name)))
    if existing is None:
        existing = Sacco(name=name)
        db.add(existing)
        db.flush()
        new_names.append(name)
    db.add(SaccoAlias(sacco_id=existing.id, alias=key))
    db.flush()
    return existing.id


def main(apply: bool):
    db = SessionLocal()
    known_aliases = list(db.scalars(select(SaccoAlias.alias)).all())
    new_names, log = [], []
    counts = {"inserted": 0, "filled": 0, "match": 0, "mismatch": 0}
    inserted_by_year = {}

    for pdf, report_year, appendix, pages, y0, y1 in SOURCES:
        raw = (RAW / pdf).read_bytes()
        extract = extract_stability_table if appendix == "stability" else extract_growth_table
        df = extract(raw, pages, y0, y1)
        fields = METRICS_WITH_LIQUIDITY if appendix == "stability" else GROWTH_METRICS
        print(f"{pdf} {appendix} pp.{pages}: {len(df)} rows extracted")

        report = db.scalar(select(Report).where(Report.report_year == report_year))
        if report is None:
            report = Report(report_year=report_year, source_file=pdf, units="Kshs billions")
            db.add(report)
            db.flush()
        page_start = int(pages.split("-")[0])

        for row in df.to_dict("records"):
            sacco_id = _sacco_for(db, row["sacco_name"], new_names)
            year = int(row["data_year"])
            metric = db.scalar(select(FinancialMetric).where(
                FinancialMetric.sacco_id == sacco_id, FinancialMetric.data_year == year))
            if metric is None:
                metric = FinancialMetric(sacco_id=sacco_id, data_year=year, report_id=report.id,
                                         source_page=page_start, data_stale=bool(row["footnote_star"]))
                db.add(metric)
                for field in fields:
                    if row.get(field) is not None and row[field] == row[field]:  # skip NaN
                        setattr(metric, field, float(row[field]))
                db.flush()
                counts["inserted"] += 1
                inserted_by_year[year] = inserted_by_year.get(year, 0) + 1
                log.append([row["sacco_name"], year, "(all)", pdf, page_start, "", "", "inserted"])
                continue
            for field in fields:
                new = row.get(field)
                if new is None or new != new:  # missing in this report
                    continue
                old = getattr(metric, field)
                if old is None:
                    setattr(metric, field, float(new))
                    status = "filled"
                elif abs(old - new) <= TOLERANCE:
                    status = "match"
                else:
                    status = "mismatch"  # kept the existing (validated) value
                counts[status] += 1
                log.append([row["sacco_name"], year, field, pdf, page_start, new, old, status])

    print("\nResult:", counts, "| inserted by data year:", dict(sorted(inserted_by_year.items())))
    if new_names:
        print(f"\n{len(new_names)} SACCO names not seen in 2022-2024 (new SACCOs or spelling variants):")
        for name in new_names:
            close = difflib.get_close_matches(normalize_name(name), known_aliases, n=1, cutoff=0.85)
            print(f"  {name}" + (f"   <- check: close to '{close[0]}'" if close else ""))
    mismatches = [r for r in log if r[-1] == "mismatch"]
    for r in mismatches[:15]:
        print("  mismatch:", r)

    if apply:
        db.commit()
        with LOG.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["sacco", "data_year", "field", "source_pdf", "page", "extracted", "existing", "status"])
            writer.writerows(log)
        print(f"\nApplied. Evidence written to {LOG.name}")
    else:
        db.rollback()
        print("\nDry run only: nothing was saved. Re-run with --apply to load.")
    db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="save to the database (default: dry run)")
    main(parser.parse_args().apply)
