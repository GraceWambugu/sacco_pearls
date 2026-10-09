"""Shared PDF-extraction logic, used by BOTH:
  - the CLI script etl/extract_stability.py (for manual/terminal use)
  - the admin panel's upload endpoint (app/routers/ingest.py), so an admin
    can upload a SASRA report PDF through the browser and have it extracted
    and loaded without touching the terminal.

Keeping this in one place means the two code paths can never silently drift
apart and produce different results from the same PDF.
"""
import os
import re
import tempfile
import warnings

import camelot
import pandas as pd

warnings.filterwarnings("ignore")

METRICS = ["cca", "ccd", "ica", "ext_borrowing", "npl_ratio"]


def _pct(x):
    """'11.28%' -> 11.28 ; '(4.29%)' -> -4.29 (accounting negatives) ; blank -> None"""
    x = re.sub(r"\s+", "", str(x))
    m = re.fullmatch(r"(\()?(-?\d+(?:\.\d+)?)%?(\))?", x)
    if not m:
        return None
    v = float(m.group(2))
    return -v if (m.group(1) and m.group(3)) else v


def _clean_name(x):
    x = re.sub(r"\s+", " ", str(x).replace("\n", " ")).strip()
    starred = x.endswith("*")
    return x.rstrip("*").strip(), starred


def extract_stability_table(pdf_bytes: bytes, pages: str, y0: int, y1: int) -> pd.DataFrame:
    """Extract the SASRA 'Financial Stability Indices for DT-SACCOs' appendix.

    pdf_bytes: raw PDF file content (e.g. read from an uploaded file)
    pages:     Camelot page range string, e.g. '174-178'
    y0, y1:    the two data years the table's paired columns represent
               (e.g. 2023, 2024)

    Returns a DataFrame with one row per (SACCO, year): rank_no, sacco_name,
    footnote_star, data_year, cca, ccd, ica, ext_borrowing, npl_ratio.
    """
    # Camelot must reopen the PDF; Windows will not allow that while its
    # temporary file handle is still open.
    fd, tmp_path = tempfile.mkstemp(suffix=".pdf")
    try:
        with os.fdopen(fd, "wb") as tmp:
            tmp.write(pdf_bytes)
        tables = camelot.read_pdf(tmp_path, pages=pages, flavor="lattice")
    finally:
        os.remove(tmp_path)

    rows = []
    for t in tables:
        for _, r in t.df.iterrows():
            if not re.fullmatch(r"\d{1,3}", str(r[0]).strip()):
                continue  # skip header / tier-heading rows
            name, star = _clean_name(r[1])
            vals = [_pct(v) for v in r[2:12]]
            for j, y in enumerate((y0, y1)):
                row = dict(rank_no=int(r[0]), sacco_name=name, footnote_star=star, data_year=y)
                for i, m in enumerate(METRICS):
                    row[m] = vals[i * 2 + j]
                rows.append(row)
    return pd.DataFrame(rows)
