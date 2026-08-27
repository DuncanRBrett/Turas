# Conjoint Session A — implementation notes

Branch: `feature/conjoint-correctness`. Spec: `HANDOVER_CONJOINT_FOR_OPUS.md` §2 (A1-A14),
findings in `CONJOINT_PRODUCTION_REVIEW_2026-07-11.md`.

**Baseline reproduced this session** (`testthat::test_dir("modules/conjoint/tests/testthat")`):
0 fail / 12 skip / 2 warnings — matches the review's 2026-07-11 baseline exactly.

Environment checks run this session: `bayesm` installed TRUE, `mlogit` TRUE, `survival` TRUE,
`node` at `/opt/homebrew/bin/node` (not the hardcoded `/usr/local/bin/node`).

---

## New findings (not in the review doc)

### A-NEW-1 — every confidence interval on the aggregate (MNL/clogit) path is NA
`calculate_ci()` (`R/99_helpers.R:190`) builds `c(lower = estimate - z*se, upper = ...)`.
`estimate` arrives as a *named* element (`utilities_raw[i]`, named after the level), so R
composes the names: the result is `lower.Samsung` / `upper.Samsung`, and the caller's
`ci["lower"]` (`R/04_utilities.R:150-157`) is therefore `NA`. Verified twice this session —
by executing the name-composition in R, and by running the full pipeline on
`modules/conjoint/examples/example_config.xlsx`, whose utilities table comes back with
`CI_Lower`/`CI_Upper` entirely `NA`.
Consequence: the default estimation path has shipped blank CIs in the utilities sheet and the
HTML report for as long as this code has existed. p-values and stars are unaffected
(`calculate_p_value` takes scalars and returns an unnamed value).
Fixed under A4 (the CI/SE honesty item), since that item already rewrites this plumbing.

---

## Deviations from the work order

(appended as they happen)
