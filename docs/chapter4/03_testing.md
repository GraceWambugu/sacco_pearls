# Testing and results (draft for Chapter 4 / Chapter 5)

Proposal section 3.6 sets five kinds of testing: unit, integration, system, black-box and
performance, plus ETL accuracy and usability. Results below were produced on 26 October 2026 on the
development laptop (Windows 11, Python 3.11, PostgreSQL 18, Flutter 3.47.7, Android emulator Pixel 8).
Rewrite in your own words; keep the numbers.

## 1. Automated tests (unit, integration and regression)

| Suite | Tool | Tests | Result | What it covers |
|---|---|---|---|---|
| Scoring rules | pytest | 20 | all pass | Every threshold boundary (10%, 12.5%, 5%, 25%...), overrides, weight rescaling, flags, minimum two dimensions, liquidity shown but not scored, real STIMA and Mwalimu cases |
| API and ETL | pytest | 52 (incl. parametrised cases) | all pass | Auth (Argon2id, JWT, password reset), CRUD, watchlists, admin upload, score, compare, rankings, trend, both stability-table layouts (12 and 14 columns), temp-file handling |
| **Backend total** | | **72** | **72 passed, 0 failed** | Run: `..\.venv\Scripts\python.exe -m pytest -q` in `backend` |
| App screens and models | flutter test | 43 | all pass | JSON parsing, providers, Home, Directory, Profile, Compare, Trends, Saved, sign-in forms; uses fake APIs so no server is needed |

The app tests acted as **regression tests** and caught real defects before the user saw them:
`setState` returning a Future (Search and Compare), and four layout overflows at phone width (score
row, hero pill, card buttons, profile header), all fixed.

## 2. ETL accuracy

Target (proposal 3.2.2): at least 95% accuracy on a sample checked against the source PDFs.

| Check | Sample | Result |
|---|---|---|
| 2022-2024 rows (reports 2023, 2024) re-extracted with a second parser (pdfplumber) and compared with the Camelot values | **All 531 rows**, not a 10% sample | **530 of 531 rows match (99.8%)**. 5 of these matched on values but the PDF splits the name across lines. 1 row (Metropolitan National 2024, stability) did not match and is flagged. Evidence: `docs/validation_log_full.csv` |
| Figures printed in two different reports (2022 report vs 2023 report for data year 2022; 2021 report vs 2022 report for data year 2021) | **2,239 figures** | **2,239 match, 0 mismatch (100%)**. Evidence: `docs/validation_older_reports.csv` |

Both results are above the 95% target. Known gaps: Camelot drops one 2020 row (USHURU), and two
SACCOs (Metropolitan National, Shoppers) show assets below loans in SASRA's own table; the app flags
these rather than correcting them.

## 3. Performance test (Locust)

Target (proposal 3.6): standard data queries in under 2 seconds.
Set-up: 50 simulated members, 10 new members per second, 2 minutes, each member searching, opening
profiles, comparing three SACCOs, viewing rankings and trends with 1 to 3 seconds between taps.
Server: one uvicorn development process on the laptop, local PostgreSQL. Script:
`backend/loadtest/locustfile.py`; raw results: `docs/chapter4/loadtest/results_stats.csv`.

| Request | Requests | Failures | Median (ms) | 95th percentile (ms) | Slowest (ms) |
|---|---|---|---|---|---|
| Search `/saccos?q=` | 711 | 0 | 17 | 78 | 794 |
| Directory `/saccos?limit=200` | 210 | 0 | 26 | 86 | 800 |
| Profile `/saccos/{id}/score` | 859 | 0 | 28 | 100 | 1,273 |
| Trend `/saccos/{id}/trend` | 392 | 0 | 34 | 110 | 720 |
| Compare (3 SACCOs) | 437 | 0 | 37 | 140 | 750 |
| Rankings (all SACCOs) | 210 | 0 | 81 | 200 | 640 |
| **All member requests** | **2,869** | **0** | **29** | **150** | **1,273** |

Result: **target met**. 95% of every request type was answered within 0.2 seconds, and the slowest
single request took 1.3 seconds.

Honest note: the first request of each simulated member (50 requests arriving within 5 seconds)
averaged 2.2 seconds, because every member started at once on a single development process. The same
request takes 0.013 to 0.018 seconds on its own. A deployed server with more than one worker would
remove this start-up queue.

## 4. Black-box test cases (mobile app)

Designed from the functional requirements (SRS) without looking at the code. "Evidence" says how the
result was obtained: an automated widget test, or a manual check on the Android emulator against the
local API. Re-run the manual ones yourself before submission and tick the last column.

| ID | Req. | Test | Input / steps | Expected output | Evidence | Result | Re-run |
|---|---|---|---|---|---|---|---|
| BB01 | FR7 | Search by name | Directory, type "stima" | List narrows to STIMA DT. within about 0.3 s of the last key | Widget test + emulator | Pass | ☐ |
| BB02 | FR7 | No match | Type "zzz" | "No SACCOs match your search" with reason and Reset | Widget test | Pass | ☐ |
| BB03 | FR7 | County filter | Choose "Kajiado" | Only Kajiado SACCOs shown | Widget test | Pass | ☐ |
| BB04 | FR7 | Rating filter | Choose "Amber (50-74.9)" | Only Amber SACCOs shown | Widget test | Pass | ☐ |
| BB05 | FR7 | Low NPL quick filter from Home | Home, tap "Low NPL" | Directory opens with only NPL of 5% or less (68 SACCOs in 2024) | Emulator | Pass | ☐ |
| BB06 | FR8 | Profile score | Open STIMA DT. | 85.0 /100, "Green rating", 4 of 6 scored | Widget test + emulator | Pass | ☐ |
| BB07 | FR4 | P and L shown honestly | Open any 2024 profile | Protection and Liquidity rows say "Not available" with the reason; no score | Widget test + emulator | Pass | ☐ |
| BB08 | FR4 | Liquidity where published | Open STIMA, choose 2022 | Liquidity row says "Shown, not scored · 72.4%" | Widget test | Pass | ☐ |
| BB09 | FR8 | Year selector | Tap 2023 on a profile | Score reloads for 2023 | Widget test | Pass | ☐ |
| BB10 | FR8 | Indicator detail | Tap "Asset quality" | NPL value, band and "How it is rated" rule shown | Widget test | Pass | ☐ |
| BB11 | FR13 | Data notes | Open a SACCO flagged anomaly (e.g. Shoppers) | "Notes on the data" explains assets below loans | Widget test | Pass | ☐ |
| BB12 | FR9 | Compare two | Add 2 SACCOs, open Compare | Ranked "1st of 2" / "2nd of 2", radar with 4 axes, indicator table | Widget test + emulator | Pass | ☐ |
| BB13 | FR9 | Compare limit | Try to add a 4th SACCO | Message "Compare already has three SACCOs" | Widget test (provider) | Pass | ☐ |
| BB14 | FR9 | Ties | Compare two SACCOs both scoring 100 | Both "Joint 1st of 2" | Widget test | Pass | ☐ |
| BB15 | FR10 | Top SACCOs | Open Home | Three top 2024 SACCOs with real assets, NPL and core capital; ties shown as "JOINT #1" | Widget test + emulator | Pass | ☐ |
| BB16 | FR11 | Trend chart | Trends, choose STIMA, metric "Total assets" | Line from 2020 to 2024 (41.1 to 66.5 KES bn) and a written assessment | API check (`/saccos/4/trend`) + widget test | Pass | ☐ |
| BB17 | FR11 | Missing years | Trends, metric "PEARLS health score" | 2020 shown as a gap with the reason, not a guessed value | Widget test | Pass | ☐ |
| BB18 | FR12 | Save needs sign-in | Signed out, tap "Save SACCO" | Sign-in page opens | Not yet run on the emulator | **To run** | ☐ |
| BB19 | FR12 | Saved list updates | Signed in, save a SACCO, open Saved | SACCO appears without pressing refresh | Emulator | Pass | ☐ |
| BB20 | FR12 | Weak password | Register with "abc" | Rejected: at least 8 characters with a letter and a digit | API test | Pass | ☐ |
| BB21 | NFR6 | Server down | Stop the API, open Directory | "Could not reach the server" and Try again; Try again works once the API is back | Widget test | Pass | ☐ |
| BB22 | NFR5 | Colour never alone | Any rating on any screen | The word Green / Amber / Red is printed beside the colour | Widget tests | Pass | ☐ |

## 5. System test (end to end)

Run on the Android emulator against the local API with the real database:
search "stima" → open profile (85.0 Green, six rows) → add to compare → add two more →
Compare shows the ranking, radar and table → Trends shows the five-year asset line. **Pass**
(screenshots in `docs/chapter4/screens/`). iOS was not tested (Windows development machine).

## 6. Usability evaluation (still to do: needs real users)

Objective vii asks for usability testing with target users. This cannot be done by the developer.
The task script and SUS questionnaire are in `04_usability_kit.md`. Plan: 5 to 10 SACCO members or
prospective members in Nairobi, 15 to 20 minutes each, then report task completion, time per task,
errors and the average SUS score (68 or above is above average).
