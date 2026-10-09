"""Review and import headquarters counties from SASRA 2024 Appendix VII.

From backend: python -m scripts.load_counties ../data/raw/sasra_2024.pdf
Add --apply after reviewing the dry-run output to update empty counties.
"""
import argparse
import re
from collections import Counter, defaultdict

import pdfplumber
from sqlalchemy import select

from app.database import SessionLocal
from app.models import Sacco
from app.utils import normalize_name

COUNTIES = """Baringo|Bomet|Bungoma|Busia|Elgeyo Marakwet|Embu|Garissa|Homa Bay|Isiolo|
Kajiado|Kakamega|Kericho|Kiambu|Kilifi|Kirinyaga|Kisii|Kisumu|Kitui|Kwale|
Laikipia|Lamu|Machakos|Makueni|Mandera|Marsabit|Meru|Migori|Mombasa|Murang'a|
Nairobi|Nakuru|Nandi|Narok|Nyamira|Nyandarua|Nyeri|Samburu|Siaya|Taita Taveta|
Tana River|Tharaka Nithi|Trans Nzoia|Turkana|Uasin Gishu|Vihiga|Wajir|West Pokot"""
COUNTY_NAMES = {re.sub(r"[^A-Z ]", " ", name.upper()).replace("  ", " ").strip(): name
                for name in COUNTIES.replace("\n", "").split("|")}
COUNTY_NAMES.update({"NAIROBI CITY": "Nairobi", "HOMABAY": "Homa Bay"})


def headquarters_county(location):
    lines = [line.strip() for line in location.splitlines() if line.strip()]
    for index, line in enumerate(lines):
        if "COUNTY" not in line.upper() or not re.fullmatch(r"[A-Z \-’']+", line):
            continue
        for start in range(max(0, index - 2), index + 1):
            source = " ".join(lines[start:index + 1])
            if not source.endswith("COUNTY"):
                continue
            key = re.sub(r"[^A-Z ]", " ", source[:-len("COUNTY")].upper())
            county = COUNTY_NAMES.get(" ".join(key.split()))
            if county:
                return county
    return None


def extract_directory(pdf_path):
    entries = []
    current = None
    with pdfplumber.open(pdf_path) as report:
        for page_number in range(184, 233):
            for table in report.pages[page_number - 1].extract_tables():
                if not table or not table[0]:
                    continue
                headquarters_column = next(
                    (index for index, cell in enumerate(table[0])
                     if cell and "PHYSICAL" in cell and "HEADQUARTER" in cell), None)
                if headquarters_column is None:
                    continue
                for row in table[1:]:
                    number = (row[0] or "").strip()
                    if number.isdigit():
                        name = next((cell for cell in row[1:headquarters_column]
                                     if cell and "SACCO" in cell.upper()), None)
                        if not name:
                            current = None
                            continue
                        current = {"number": int(number), "name": " ".join(name.split()),
                                   "page": page_number, "location": ""}
                        entries.append(current)
                    if current and row[headquarters_column]:
                        current["location"] += "\n" + row[headquarters_column]

    for entry in entries:
        entry["county"] = headquarters_county(entry["location"])
    return entries


def import_counties(entries, db, apply=False):
    by_name = defaultdict(list)
    for sacco in db.scalars(select(Sacco)):
        by_name[normalize_name(sacco.name)].append(sacco)

    by_key = defaultdict(list)
    for entry in entries:
        by_key[normalize_name(entry["name"])].append(entry)

    matched = []
    review = []
    for key, source_rows in by_key.items():
        targets = by_name.get(key, [])
        if len(source_rows) != 1 or len(targets) != 1 or not source_rows[0]["county"]:
            review.extend((row["number"], row["name"], row["page"], row["county"],
                           "ambiguous name or missing county") for row in source_rows)
            continue
        source = source_rows[0]
        target = targets[0]
        if target.county:
            if normalize_name(target.county) != normalize_name(source["county"]):
                review.append((source["number"], source["name"], source["page"],
                               source["county"], f"existing county: {target.county}"))
            continue
        matched.append((target, source))

    if apply:
        for target, source in matched:
            target.county = source["county"]
        db.commit()
    return matched, review


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", help="2024 SASRA Annual Supervision Report PDF")
    parser.add_argument("--apply", action="store_true", help="Update only confidently matched, empty counties")
    args = parser.parse_args()

    entries = extract_directory(args.pdf)
    numbers = Counter(entry["number"] for entry in entries)
    if len(entries) < 170 or any(count != 1 for count in numbers.values()):
        parser.error("Directory extraction is incomplete or has duplicate row numbers; database untouched")
    with SessionLocal() as db:
        matched, review = import_counties(entries, db, apply=args.apply)
    print(f"Directory rows: {len(entries)} | counties found: {sum(bool(e['county']) for e in entries)}")
    missing_numbers = sorted(set(range(1, 179)) - set(numbers))
    print(f"PDF row numbers not extracted: {missing_numbers}")
    print(f"{'Updated' if args.apply else 'Ready to update'}: {len(matched)} existing SACCOs")
    for target, source in matched[:8]:
        print(f"  {target.name} -> {source['county']} (PDF page {source['page']})")
    print(f"Needs review: {len(review)}")
    for number, name, page, county, reason in review:
        print(f"  #{number} {name} | {county or 'no county'} | page {page}: {reason}")


if __name__ == "__main__":
    main()