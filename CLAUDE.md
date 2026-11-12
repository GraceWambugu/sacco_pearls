# SACCO PEARLS (SACCOLens): project brief

## What this is
A final-year project (Strathmore BBIT): a mobile decision-support system that helps people choose a
deposit-taking SACCO in Kenya. It reads SASRA's Annual Supervision Reports (PDF), extracts per-SACCO
figures, stores them in PostgreSQL, scores each DT-SACCO with a RULES-BASED, PEARLS-aligned method,
and serves the results through FastAPI to a Flutter app. This is NOT machine learning. Never describe
it as AI or ML in code comments or documents, and never claim SASRA endorses it.

## The person you are helping
Grace is a student who must explain and defend every line to her supervisor. Prefer simple, readable
code. Briefly explain what you change and why. Make small commits. Use Windows PowerShell commands.

## Environment
Windows, VS Code, Python 3.11, virtual environment in `.venv` at the repo root. FastAPI, SQLAlchemy 2,
PostgreSQL 18 (database `sacco_db`, port 5432), Argon2id (argon2-cffi), JWT (PyJWT), Camelot (lattice)
for PDF tables, pdfplumber for cross-checks. Flutter 3.47 (dio, provider, fl_chart, google_fonts 8;
version 9 does not work with this Flutter). Android emulator `Pixel_8`.

## Commands
- Backend tests (from `backend`): `..\.venv\Scripts\python.exe -m pytest -q`
- Server (from `backend`): `..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0`
- App (from `mobile`): `flutter run` (press `r` reload, `R` restart, `q` quit); tests: `flutter test`
- Older reports: `python -m scripts.load_older_reports` (dry run) then `--apply`

## Layout
- `backend/app/`: main, models, schemas, security, deps, database, config, utils, etl, scoring
- `backend/app/routers/`: auth, users, saccos, metrics, watchlists, ingest, ingest_growth, scores
  (scores: `/saccos/{id}/score`, `/compare`, `/rankings`, `/saccos/{id}/trend`)
- `backend/scripts/`: create_admin, reset_password, load_stability, load_counties, load_older_reports
- `backend/loadtest/locustfile.py`; `backend/tests/`
- `mobile/lib/`: `core/` (config, dio client), `models/`, `providers/` (auth, compare, saved),
  `screens/` (app_shell, home, directory, profile, compare, trends, saved, auth, account),
  `widgets/` (ui, rating, radar, summary), `theme/` (dark slate + emerald)
- `admin/`: login.html and admin.html (partly written by Copilot; read before editing)
- `docs/`: scoring_design.md (read before touching scoring), validation logs, `chapter4/` drafts

## Data facts
- Loaded: data years 2020 (sizes only, not rated), 2021-2024 (sizes and ratios). Liquidity only for
  2021 and 2022 (2022 report). Each report holds two data years; figures agree across reports
  (2,239 of 2,239 cross-checked).
- `financial_metrics` is unique per (sacco_id, data_year). Same SACCO, different spelling is merged
  through `sacco_aliases` (normalize_name) and the `SAME_SACCO` map in the loader.
- Never overwrite validated figures; the loader only inserts missing rows and fills empty fields.
- Test SACCOs "grace", "dummy sacco 2" and "string" exist in the local database (no figures).

## Scoring (docs/scoring_design.md)
Scored: Effective structure 40%, Asset quality 30%, Growth 20%, Returns 10% (a proxy). Protection is
never published; Liquidity is shown where published but not scored (Grace's Option A). Green 75+,
Amber 50+, else Red. A regulatory breach caps at Amber; negative core capital or NPL above 25% forces
Red. A rating needs at least two scored dimensions. Scores are computed on request (pearls_scores is
unused). All thresholds are constants at the top of `backend/app/scoring.py`.

## App rules
Ratings always show the word (Green/Amber/Red), never colour alone. Every screen has loading, empty
and error states ("Could not reach the server" + Try again). Only real API data is shown: no invented
dividends, P/L scores or 80/60 bands from the design mock-up.

## Rules for you
- Never read, print or commit `backend/.env` or any secret.
- Work on a branch named `feature/<topic>`. Do not push, merge or delete branches without asking.
- Run the tests before every commit. Do not change the database schema or delete data without asking.
- Ask before big refactors. Show a plan before multi-file changes.
