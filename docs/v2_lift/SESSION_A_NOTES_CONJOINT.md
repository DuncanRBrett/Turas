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

### A-NEW-2 — six console warnings fire on the *success* branch
`R/07_output.R` carried the "Saving without part reconciliation" warning pasted
into six unrelated `else` blocks: every non-formula string cell escaped
(`:51`), "no coefficients available" (`:440`), an unmapped column name
(`:681`), a Geweke check that PASSED (`:867`), an ESS check that PASSED
(`:882`), and an RLH check that PASSED (`:1015`). On an HB run that is one
false alarm per diagnostics row. Because the same text is also the *genuine*
warning that a workbook was written without `turas_saveWorkbook` — the one that
means Excel may offer to repair the file — the false copies drown the real
signal. The six mis-pasted copies are removed; the two legitimate sites
(`:37`, the shared-library-absent notice at load time, and `:199`, the actual
fallback save) stay.

### A-NEW-3 — TRS `CALC_` refusals came out blaming the config
`conjoint_refuse()` (`R/00_guard.R`) prefix-checked against a list that omitted
`CALC_`, although the project CLAUDE.md names it and the shared
`.trs_valid_prefixes` (`modules/shared/lib/trs_refusal.R:38-48`) allows it. Any
`CALC_*` code was silently rewritten to `CFG_CALC_*`, which tells the user their
configuration is wrong when the failure was a calculation. `CALC_` added.

### A-NEW-4 — sequential best-worst estimation recurses until the stack gives out
`estimate_best_worst_sequential()` (`R/10_best_worst.R`) passed the study's own
config to `estimate_choice_model()` for each of its two sub-models. That config
carries `estimation_method = "best_worst"`, so `estimate_choice_model` dispatched
straight back into `estimate_best_worst_model` and recursed. It was unreachable
in production only because H2's validator refused `best_worst` before the run
started — so fixing H2 (A5) exposes it. The sub-models now run under a config
with `estimation_method = "auto"`. Found by the new sequential-recovery test,
which is the first test in this module ever to estimate a best-worst model.

### A-NEW-5 — the implicit-None path writes a string into a numeric column
`create_none_rows()` (`R/09_none_handling.R`) set the synthesised None row's
`alternative_id` to the literal `"NONE"`. When the data's alternative id is
numeric — which it is in every generic Turas layout — the `bind_rows()` in
`handle_implicit_none()` then fails outright with an incompatible-type error.
The path was unreachable while H1 stopped implicit-None detection from ever
firing, so fixing H1 (A6) exposes it. Numeric id columns now get one past the
highest existing id; non-numeric ones still get `"NONE"`.

---

## Deviations from the work order

**A4 — the SE column contract.** The two extractors disagreed on the column
name: the aggregate path emitted `Std_Error`, the HB path emitted `SE`, and
`lib/html_report/02_table_builder.R:56` tests for `"SE"` — so the HTML report
has been showing a Std. Error column on HB runs and never on MNL runs. Rather
than rename one and chase the consumers, both paths now emit `Std_Error` as the
canonical column *and* `SE` as an alias with the same values, plus
`Heterogeneity_SD`. No consumer breaks and the report gains the column on the
MNL path. `R/14_willingness_to_pay.R:281-283` already handled both names.

**A4 — p-values in the tail.** `2 * (1 - pnorm(|z|))` returns exactly 0 from
about |z| = 8.3, so the workbook has been printing `p = 0`. Changed to
`2 * pnorm(-|z|)` at all three sites, which is accurate to ~1e-300. A p-value
of exactly zero is not a number any survey result should carry.

**A2 — `setwd` unwinding.** The work order said to add `on.exit`. The `setwd`
sits inside a `withProgress()` expression in a Shiny observer, where `on.exit`
binds to an ambiguous frame; `tryCatch(..., finally = setwd(old_wd))` restores
the directory at exactly the right moment with no frame ambiguity. Same intent.
