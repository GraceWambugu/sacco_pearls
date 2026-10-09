# SACCO PEARLS App (prototype)
Mobile SACCO membership decision system using PEARLS-based benchmarking.

## Layout
- `etl/`      PDF extraction (Camelot) -> cleaned CSV
- `backend/`  FastAPI + SQLAlchemy + PostgreSQL (Argon2id hashing, JWT, CRUD)
- `data/raw/` SASRA PDFs (renamed by REPORT year)
- `docs/`     SRS, diagrams, wireframes, validation logs

## Run (from repo root, venv active)
    pip install -r requirements.txt
    cd backend
    copy .env.example .env        # then edit .env
    pytest -v                     # tests use SQLite, no Postgres needed
    uvicorn app.main:app --reload # open http://127.0.0.1:8000/docs
    python -m scripts.create_admin you@example.com "YourPass1" "Your Name"
    python -m scripts.load_stability ../data/processed/stability_2024_report.csv --report-year 2024 --source sasra_2024.pdf --page 174

## Headquarters counties from the 2024 directory
Appendix VII of the SASRA 2024 PDF lists DT-SACCO headquarters and counties.
From `backend`, preview unique matches against existing SACCOs before applying:

    python -m scripts.load_counties ../data/raw/sasra_2024.pdf
    python -m scripts.load_counties ../data/raw/sasra_2024.pdf --apply

Only blank counties with a unique name match are filled. Missing PDF rows and
unmatched names are reported for manual review; existing counties are preserved.
