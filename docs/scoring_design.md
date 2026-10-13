# PEARLS-Aligned Scoring Engine — Design (draft v0.2)

## 1. What it is

A **rules-based decision-support method**. It compares each DT-SACCO's published ratios with fixed thresholds and combines the results into a Green / Amber / Red rating. Nothing is learned from data, so this is not machine learning. Every threshold is either printed in a SASRA or WOCCU source or listed in section 8 as a design choice.

It is **PEARLS-aligned, not a full PEARLS assessment**. SASRA publishes only a few ratios per SACCO, so the score covers part of PEARLS (section 2). The rating always shows how many of the six dimensions were scored.

## 2. What the data supports

| PEARLS dimension | Available per SACCO (2022-2024)? | How it is used |
|---|---|---|
| **P**rotection | No. Loan-loss provisions are not published per SACCO | Not scored. Reported as a data gap |
| **E**ffective financial structure | Yes: core capital/assets (CCA), core capital/deposits (CCD), institutional capital/assets (ICA), external borrowing/assets | Scored (4 indicators) |
| **A**sset quality | Partly: NPL ratio only | Scored (1 indicator) |
| **R**ates of return and cost | Weak: only total income / total assets, a yield proxy | Scored with low weight, relative to peers |
| **L**iquidity | No for 2023 and 2024. The 2022 report has a liquidity ratio that is not yet loaded | Not scored. Reported as a data gap |
| **S**igns of growth | Yes, from 2023: year-on-year growth in assets, deposits and loans | Scored (3 indicators) |

So 4 of 6 dimensions are scored (3 of 6 for 2022 rows, which have no prior year to measure growth against).

## 3. Indicator rules

Each indicator is mapped to a band: Green = 100 points, Amber = 50, Red = 0.

| Indicator | Red | Amber | Green | Source |
|---|---|---|---|---|
| CCA | below 10% | 10% to under 12.5% | 12.5% or more | SASRA minimum 10% (2024 report, pp.174-175) |
| CCD | below 8% | 8% to under 10% | 10% or more | SASRA minimum 8% (pp.174-175) |
| ICA | below 8% | 8% to under 10% | 10% or more | SASRA minimum 8% (pp.174-175); WOCCU target about 10% |
| External borrowing / assets | above 25% | above 18.75% to 25% | 18.75% or less | SASRA maximum 25% (pp.174-175) |
| NPL ratio | above 10% | above 5% to 10% | 5% or less | WOCCU: no more than 5% delinquency. The 10% Red line is a design choice |
| Growth in assets, deposits, loans | below 0% | 0% to under inflation | at or above inflation (real growth) | WOCCU: real positive growth. Inflation: 7.67% (2023), 4.50% (2024), KNBS annual averages via the Central Bank of Kenya |
| Income / total assets | below 75% of the peer median | 75% of median up to the median | at or above the median | Peer-relative proxy. Design choice |

Green means at least 25% better than the regulatory limit. This margin is one adjustable parameter.

## 4. From indicators to a rating

1. **Dimension score** = average points of its indicators.
2. **Composite** = weighted average of the dimensions that have data: E 40%, A 30%, S 20%, R 10%. If a dimension has no data, the remaining weights are rescaled so they still sum to 100%.
3. **Band:** Green 75 or more, Amber 50 to under 75, Red under 50.
4. **Overrides** (a strong dimension must not hide a serious problem):
   - Core capital below zero: always Red.
   - Any regulatory breach (an Effective-structure indicator in Red): rating capped at Amber.
   - NPL above 25% of the loan book: Red (adopted default, see section 7).
5. **Data flags**, shown next to the rating without changing it:
   - `stale`: SASRA marked the row with an asterisk, so figures may be carried forward.
   - `anomaly`: total assets below gross loans, which is impossible, so the source table is suspect.
   - `limited`: fewer than 4 dimensions scored.

## 5. Worked example (2024 data)

| | CCA | CCD | ICA | Ext. borrow. | **E** | NPL | **A** | **S** | **R** | **Composite** |
|---|---|---|---|---|---|---|---|---|---|---|
| STIMA DT. | Green | Green | Green | Green | 100 | Amber | 50 | 100 | 100 | **85.0, Green** |
| MWALIMU NATIONAL DT. | 14.01 Green | 18.49 Green | 9.96 Amber | 1.79 Green | 87.5 | 8.26 Amber | 50 | 83.3 | 50 | **71.7, Amber** |

Mwalimu National's ICA of 9.96% falls just under the 10% Green line, which is a good illustration of how a boundary decides a rating.

## 6. Trial run on the 531 loaded rows

| Year | Green | Amber | Red |
|---|---|---|---|
| 2022 | 91 | 57 | 26 |
| 2023 | 82 | 68 | 30 |
| 2024 | 82 | 69 | 26 |

Before the NPL override was added the counts were 91/70/13, 82/83/15 and 82/85/10.

- The spread is sensible: no year is dominated by one rating.
- All 5 SACCOs with negative core capital (Jitegemee, Lamu Teachers, Metropolitan National, Ndosha, Shoppers) are Red on score alone, so the negative-capital override never has to fire with the current data.
- Overrides in 2024: 9 ratings capped at Amber by a regulatory breach, and 16 forced to Red by NPL above 25%.
- The `anomaly` flag (assets below loans) appears for Metropolitan National and Shoppers in every year, and for K-Pillar in 2022.

## 7. Weaknesses found in the trial, and fixes

1. **Severe NPL hidden by other dimensions.** DUMISHA has an NPL ratio of 93.43% but is Amber (50.0), because its capital ratios look healthy. 16 SACCOs in 2024 with NPL above 25% are Amber. *Fix adopted:* an override sets NPL above 25% to Red. It moves 16 SACCOs from Amber to Red in 2024 (Red 10 to 26). A stricter 50% line would move only 2 (DUMISHA and SOUTHER STAR DT.). I chose 25% as the default because, for a member-facing tool, a false Green costs members more than a false Red. The line is a judgement call, so confirm it with the supervisor; it is one constant (`NPL_CRITICAL_ABOVE`) in `scoring.py`.
2. **Weight sensitivity.** Changing the weights moves many ratings: with equal weights 41 of 177 2024 ratings change, and with 50/25/15/10 weights 30 change. The app should therefore always show the dimension scores next to the composite, never the composite alone.
3. **Ties at the top.** Several SACCOs score exactly 100, so comparing two top SACCOs gives a tie. A continuous (0-100) sub-score within each band would fix this and is a v2 option.

## 8. Design choices not taken from a source

The 25% margin for Green, the 10% NPL Red line, the NPL override line, the component weights, the Green/Amber score cut-offs (75 and 50), the peer-median rule for income, and the choice of 3 growth indicators. All are constants in one configuration block so they can be changed in one place.

## 9. Planned API

- `GET /saccos/{id}/score?year=2024` returns dimension scores, composite, rating, flags and the list of dimensions not scored.
- `GET /compare?ids=1,2,3&year=2024` returns the same for up to 3 SACCOs, matching the watchlist limit.

## 10. Planned tests

Boundary values for each indicator (exactly 10%, 12.5%, 5%, 25%), the overrides, weight rescaling when growth is missing, flag behaviour, and 3 to 5 real SACCOs with hand-calculated expected scores.

## 11. Limitations to state

- Protection and Liquidity are not scored, because SASRA does not publish the data per SACCO for the loaded years.
- The Returns dimension is a proxy: gross income over assets, not net surplus or yield on loans.
- Ratings describe published figures. They are not a prediction of failure and not financial advice.
- Some source rows are carried forward or inconsistent (flagged, not corrected).

## 12. Implementation status

- `backend/app/scoring.py`: the rules (pure Python, all constants in one block).
- `backend/app/routers/scores.py`: `GET /saccos/{id}/score` and `GET /compare`.
- `backend/tests/test_scoring.py` (18 unit tests) and `backend/tests/test_scores_api.py` (8 API tests).
- Check on real data: with the NPL override switched off, the engine reproduced the earlier prototype's rating and composite for all 531 loaded rows (0 differences).
