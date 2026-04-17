# Brand module test fixtures

Hand-calculated data sets for known-answer tests of the funnel element
(FUNNEL_SPEC_v2.md §10.1). Each CSV is 10 respondents × 3 brands
(IPK / ROB / CART) — small enough that every expected value can be
verified with a spreadsheet.

Files
-----
- `funnel_transactional_10resp.csv` — FMCG shape (5 stages)
- `funnel_durable_10resp.csv`       — durable shape (4 stages, OWNER + TENURE)
- `funnel_service_10resp.csv`       — service shape (4 stages, CUSTOMER + TENURE + PRIOR)

Expected values (pre-computed by hand)
--------------------------------------
See the `expected_*` constants at the top of each
`test_funnel_{category_type}.R` for the hand-calculated targets. The
table comments in each test file show the derivation of every value.

Tenure thresholds used in the fixtures: `tenure_threshold = 3`.
Attitude scale: 1 = Love, 2 = Prefer, 3 = Ambivalent, 4 = Reject,
5 = No opinion.

Focal brand for every fixture: `IPK`.
