# Software Requirements Specification (draft for Chapter 4)

System: **SACCOLens**, a mobile decision-support system that benchmarks Kenyan deposit-taking SACCOs (DT-SACCOs) with a rules-based, PEARLS-aligned score built from SASRA's Annual Supervision Reports.

Draft written from the system as built (October 2026). Rewrite in your own words before submission.

## 1. Purpose and scope

The system extracts per-SACCO figures from SASRA PDF reports (2020 to 2024 reports loaded), stores them in PostgreSQL, scores each DT-SACCO with fixed rules and serves the results through a FastAPI REST API to a Flutter mobile application. It does not give financial advice, does not predict failure, and covers DT-SACCOs only (proposal section 1.7.2).

## 2. Users (actors)

| Actor | Description | Needs to sign in? |
|---|---|---|
| Member / prospective member | Searches, views, compares and follows SACCOs | Only to save SACCOs |
| System administrator | Uploads new SASRA reports and corrects data | Yes (admin role) |
| SASRA report (external source) | Annual PDF supplying the figures | Not applicable |

## 3. Functional requirements

| ID | Requirement | Objective | Where it is met |
|---|---|---|---|
| FR1 | The administrator can upload a SASRA report PDF and choose the appendix pages; the system extracts the per-SACCO tables. | iv | Admin panel, `POST /ingest/stability`, `POST /ingest/growth` |
| FR2 | The ETL stores one record per SACCO per data year and matches the same SACCO across reports despite spelling differences. | iv | `financial_metrics` (unique SACCO + year), `sacco_aliases`, `normalize_name` |
| FR3 | The ETL never overwrites a figure already loaded; overlapping years are cross-checked. | iv, vii | `scripts/load_older_reports.py`, `docs/validation_older_reports.csv` |
| FR4 | The system scores each SACCO-year on the PEARLS dimensions the data supports (E, A, R, S) and reports P and L as not scored, with the reason. | iii, v | `app/scoring.py`, `GET /saccos/{id}/score` |
| FR5 | The composite score (0 to 100) is mapped to Green (75+), Amber (50 to 74.9) or Red (below 50), with safety overrides (regulatory breach caps at Amber; negative core capital or NPL above 25% forces Red). | v | `app/scoring.py` |
| FR6 | A SACCO is rated only when at least two dimensions can be scored. | v | `MIN_DIMENSIONS_FOR_RATING` |
| FR7 | A member can search SACCOs by name and filter by county, health rating and low NPL. | vi | Directory tab, `GET /saccos`, `GET /rankings` |
| FR8 | A member can view a SACCO profile: composite, rating word, year selector, plain summary, radar chart, all ratios used, six PEARLS rows, notes and disclaimer. | vi | Profile screen |
| FR9 | A member can compare two or three SACCOs side by side with ranks (ties shown as joint), a radar chart and an indicator table. | vi | Compare tab, `GET /compare` |
| FR10 | The Home screen lists the top-scoring SACCOs for the latest year. | vi | Home tab, `GET /rankings` |
| FR11 | A member can see a SACCO's score and key figures over the years as a chart; missing years are shown as gaps, not guessed. | vi | Trends tab, `GET /saccos/{id}/trend` |
| FR12 | A member can register, sign in, reset a forgotten password by email, and save up to three SACCOs. | vi | `/auth/*`, `/watchlists`, Saved page |
| FR13 | Data flags (stale, anomaly, limited) are shown in plain words. | v, vi | Profile "Notes on the data" |

## 4. Non-functional requirements

| ID | Category | Requirement | How it is checked |
|---|---|---|---|
| NFR1 | Performance | Standard data queries respond in under 2 seconds (proposal 3.6). | Locust load test (see testing document) |
| NFR2 | Accuracy | Extraction accuracy of at least 95% on a sample checked against the PDFs. | Validation logs: 531 rows (2022 to 2024) checked with a second parser; 2,239 figures printed in two reports compared |
| NFR3 | Security | Passwords stored only as Argon2id hashes; JWT access tokens expire (60 minutes); admin-only endpoints require the admin role; reset tokens stored only as SHA-256 digests and expire after 20 minutes. | `app/security.py`, API tests |
| NFR4 | Transparency | Every threshold is a named constant with its source; every rating can be traced to indicator bands shown in the app. | `scoring.py` config block, `docs/scoring_design.md`, Profile "How it is rated" |
| NFR5 | Accessibility | Ratings are never shown by colour alone: the words Green, Amber or Red are always printed. | Widget tests check the rating word |
| NFR6 | Usability | Every screen has loading, empty and error states; an unreachable server shows "Could not reach the server" with Try again. | Widget tests |
| NFR7 | Maintainability | Automated tests for the API, scoring and app screens. | 72 backend tests (pytest), 43 app tests (flutter test) |
| NFR8 | Portability | One Flutter code base for Android and iOS. | Tested on Android (Pixel 8 emulator); iOS not tested because development was on Windows |
| NFR9 | Honesty of claims | The app never presents itself as AI or machine learning, never claims SASRA endorsement, and states that ratings are not financial advice. | Disclaimers on Home, Profile, Compare and Trends |

## 5. Constraints and assumptions

- SASRA publishes only some PEARLS inputs per SACCO. Protection (loan-loss provisions) is never published; liquidity appears only in the 2022 report (data years 2021 and 2022), so it is shown but not scored.
- The 2020 and 2021 reports have no stability appendix, so data year 2020 has sizes only and is not rated.
- Growth (S) needs the previous year and an inflation figure; inflation is configured for 2023 and 2024 only (KNBS annual averages).
- Figures can be carried forward or inconsistent in the source tables; these are flagged, not corrected.

## 6. Changes from the proposal (to explain in the report)

| Proposal | Built | Reason |
|---|---|---|
| Firebase Authentication | Own sign-in (Argon2id + JWT) | One user store, no external dependency; password reset handled by the API |
| All endpoints secured with JWT | Read endpoints public; JWT protects saving, accounts and admin | The data is public (open government data); members should not need an account to look |
| Six scored dimensions | Four scored; P and L reported as not available | SASRA does not publish the inputs per SACCO (this answers objective iii) |
| Scores stored in `pearls_scores` | Scores computed on request | Always reflects the current rules; responses still well under 2 seconds |
| Tabula as second extractor | pdfplumber for cross-checks | Used for the independent validation of the Camelot output |
| ETL as a scheduled job | Admin upload in the browser plus a loader script | SASRA publishes once a year; an admin upload is the yearly run |
