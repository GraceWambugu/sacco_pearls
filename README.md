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

## Forgotten password (local account recovery)
From `backend`, using the same environment and database as the running API:

    python -m scripts.reset_password

Enter the existing account email, then enter and confirm a new password at the
hidden prompts. Passwords must contain at least 8 characters, a letter and a digit.
This preserves the account role. The create-admin script does not reset passwords
for existing accounts. This recovery command is for trusted local operators only.

## Mobile member accounts
The mobile app supports member registration and sign-in. Passwords are validated
for at least eight characters with a letter and a digit, then stored by the API
as Argon2id hashes with per-password random salts. Mobile access tokens are kept
in Android secure storage.

For Android Emulator development, start the API from `backend` so the emulator
can reach the host machine:

    ..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0

The app uses `http://10.0.2.2:8000` for the Android Emulator host bridge. Change
the API base URL before using a physical phone or deploying the app.

### Mobile forgot password
Copy the SMTP settings from `backend/.env.example` into the ignored
`backend/.env` file. Configure the SMTP host, port, sender address, username,
and an email-provider app password; use SSL on port 465 or STARTTLS on port 587.
Restart the API after changing `.env`. Until SMTP is configured, the reset
request endpoint returns `503` and the app shows that email delivery is
unavailable. When configured, reset emails contain a one-time token that expires
after 20 minutes. Only a SHA-256 digest of that token is stored by the API.

## Headquarters counties from the 2024 directory
Appendix VII of the SASRA 2024 PDF lists DT-SACCO headquarters and counties.
From `backend`, preview unique matches against existing SACCOs before applying:

    python -m scripts.load_counties ../data/raw/sasra_2024.pdf
    python -m scripts.load_counties ../data/raw/sasra_2024.pdf --apply

Only blank counties with a unique name match are filled. Missing PDF rows and
unmatched names are reported for manual review; existing counties are preserved.
