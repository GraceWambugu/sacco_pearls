"""Extract SASRA 'Financial Stability Indices for DT-SACCOs' (per-SACCO) with Camelot lattice.
Usage: python extract_stability.py <pdf> <pages e.g. 174-178> <prior_year> <current_year> <out.csv>
"""
import re, sys, warnings
import camelot, pandas as pd
warnings.filterwarnings("ignore")

METRICS = ["cca", "ccd", "ica", "ext_borrowing", "npl_ratio"]

def pct(x):
    """'11.28%' -> 11.28 ; '(4.29%)' -> -4.29 (accounting negatives) ; blanks/dashes -> None"""
    x = re.sub(r"\s+", "", str(x))            # also fixes '(1172.81%\n)'
    m = re.fullmatch(r"(\()?(-?\d+(?:\.\d+)?)%?(\))?", x)
    if not m:
        return None
    v = float(m.group(2))
    return -v if (m.group(1) and m.group(3)) else v

def clean_name(x):
    x = re.sub(r"\s+", " ", str(x).replace("\n", " ")).strip()
    starred = x.endswith("*")
    return x.rstrip("*").strip(), starred

def extract(pdf, pages, y0, y1):
    tables = camelot.read_pdf(pdf, pages=pages, flavor="lattice")
    rows = []
    for t in tables:
        for _, r in t.df.iterrows():
            if not re.fullmatch(r"\d{1,3}", str(r[0]).strip()):
                continue                      # skip headers / tier rows
            name, star = clean_name(r[1])
            vals = [pct(v) for v in r[2:12]]
            for j, y in enumerate((y0, y1)):
                row = dict(rank_no=int(r[0]), sacco_name=name, footnote_star=star, data_year=y)
                for i, m in enumerate(METRICS):
                    row[m] = vals[i * 2 + j]
                rows.append(row)
    return pd.DataFrame(rows)

if __name__ == "__main__":
    pdf, pages, y0, y1, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    df = extract(pdf, pages, y0, y1)
    df.to_csv(out, index=False)
    print(df.shape, "->", out)
