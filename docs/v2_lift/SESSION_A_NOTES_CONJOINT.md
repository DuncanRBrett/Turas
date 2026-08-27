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

### A-NEW-6 — two TRS refusals crashed instead of refusing
`prepare_bayesm_data()` (`R/11_hierarchical_bayes.R`) called `conjoint_refuse()`
with `message =`, an argument that function does not have, in both
`DATA_INCONSISTENT_ALTERNATIVES` and `DATA_NO_CHOICE`. Instead of a refusal the
user got a raw R "unused argument" error — on the data-validation path, which is
precisely where the refusal text is the whole point. Both survived because the
HB tests always skipped. Both now supply `title`/`problem`/`why_it_matters`.
`test_refusal_call_shapes.R` walks the parse tree of all ~100 `conjoint_refuse`
call sites in `R/` and `lib/` and fails on any unknown or missing argument, so
this class of defect cannot come back quietly.

### A-NEW-7 — C3 was live on the latent-class path too (found in the adversarial pass)
`build_latent_class_result()` (`R/13_latent_class.R`) builds its own result
object and set `std_errors <- apply(individual_betas, 2, sd)` — the same
heterogeneity-as-standard-error defect as C3, in a second place the review
named only in passing. Fixing `extract_hb_results` did not touch it. Caught by
running a latent-class model end to end after A14: the LC intervals were about
3.3x wider than the HB intervals on the same data (mean SE 0.79 vs 0.21).
`build_latent_class_result` now calls the same `compute_hb_population_se()`,
using the burn-in count `extract_lc_solution` already computed, and reports
heterogeneity in its own field. Re-measured after the fix: SE 0.24 against
heterogeneity 0.79.

### A-NEW-8 — a latent-class fit with no comparable criterion failed on a list index
When every fitted K returns an NA information criterion — which happens on
samples too small for the class count — `which.min()` returns `integer(0)` and
the code indexed the solutions list with it, producing "attempt to select less
than one element in get1index". Now refuses as
`CALC_LC_NO_COMPARABLE_SOLUTION`, naming the sample-size guidance. Reproduced
at 40 respondents, and covered by a test at that size.

### A-NEW-9 — HB and LC crashed inside bayesm when their settings were absent
`as.integer(NULL)` is `integer(0)`, and `if (NULL < 2)` is an error rather than
`FALSE`. The MCMC and class-count settings are always supplied by
`load_conjoint_config`, but `estimate_choice_model` is also a direct API, and
through it an absent `hb_ncomp` reached bayesm as an empty prior and failed
inside the package. `validate_hb_config`, `validate_latent_class_config`,
`estimate_hierarchical_bayes` and `estimate_latent_class` now fall back to the
loader's own defaults.

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

**A8 — refuse rather than implement the None ASC.** The work order allowed
either. Refusing, because implementing only the engine half would leave an
estimated none utility that nothing consumes: the simulator still defaults
`noneUtility` to 0 (`simulator_engine.js:196-198`) and wiring it is explicitly
Session B, B1. A none utility that is estimated and then ignored produces the
same wrong shares as one that was never estimated, but now with the appearance
of having been handled. The three pieces — design constant, reference-level
handling on None rows, simulator export — belong in one change.

*Correcting the review's "unverified" note on what mlogit does with all-NA
rows:* it does not drop them silently. Verified this session on a 40-respondent
explicit-None dataset — the run refused as `CFG_EST_MLOGIT_FAILED` with the
problem text "missing value where TRUE/FALSE needed", which names neither the
cause nor a fix. The new refusal names both.

**A9 — the interaction honesty gate is a skip, not a run-killing refusal.**
`predict_market_shares()` refuses outright (`CALC_INTERACTIONS_NOT_IN_SIMULATOR`)
for direct API callers. In the pipeline, though, the Excel workbook — including
the interaction analysis sheets that carry the real result — is already written
by the time the HTML report is built, so `00_main.R` step 8 skips the report,
prints the same code and reason in a console block and records a PARTIAL event,
rather than refusing and discarding a complete deliverable. Interaction
coefficients dropped from the utilities table are announced on the console
(`CONJ_INTERACTIONS_NOT_IN_UTILITIES`) and tagged on the data frame, so the drop
is never silent. Representing interactions as rows in the part-worth table was
the alternative; it was not taken because an interaction "attribute" would then
enter the importance calculation and change what that table means.

**A11 / locked decision 7 — one premise does not hold; three functions kept.**
Decision 7 says to delete the orphaned optimizer functions and
`predict_shares_with_ci`, with the rationale "none has a caller or a test".
Checked this session: all three *do* have tests.
`optimize_product_exhaustive` and `optimize_product_greedy` are exercised by
`tests/testthat/test_optimizer.R`, and `predict_shares_with_ci` by
`tests/testthat/test_simulator_ci.R` (27 assertions). Deleting them would
delete working coverage on a premise that is false, so the split taken is:

- **Deleted:** the decorative *config surface* — the OPTIMIZER template
  section, its validator block, and the two config-object fields. Nothing read
  them, and the template's own "greedy" value was refused by a validator that
  accepted only "exhaustive" or "genetic". Also removed from the user manual
  and README.
- **Kept:** the three functions, as a direct API. `predict_shares_with_ci`
  gains a roxygen note saying it is unwired and that its single-Gumbel-draw
  design injects Monte Carlo noise into the intervals, which must be fixed
  before anything calls it.

**Duncan's ruling wanted** on whether the three tested-but-unwired functions
should still be deleted. Nothing else in Session A depends on the answer.

**A14 / H11 — three guards fixed rather than deleted, one deleted.** The work
order said to wire the guards at their natural steps and delete what stays
uncalled. Wiring them exposed that three had never been executed against a real
config and did not work:

- `validate_conjoint_attributes()` counted rows per attribute, which assumes a
  long-format Attributes sheet. The loader builds it wide (one row per
  attribute, comma-separated `LevelNames` plus a parsed `levels_list`), so it
  reported "Attribute 'Brand' has only 1 level" for a perfectly valid config
  and refused the run. It now reads levels the way the rest of the module does.
- `validate_wtp_config()` did `!is.na(price_attr)` on a value that is NULL
  whenever `wtp_price_attribute` is blank — `is.na(NULL)` is `logical(0)` and
  `if (logical(0))` is an error — and `config$wtp_method %in% ...` had the same
  problem. Both cases are the normal one.
- `validate_html_config()` had the same `is.na(NULL)` hazard on both colour
  settings.

Deleted: `validate_conjoint_design()`, which validated a "Design sheet" this
module has no concept of, with no caller and no test. `conjoint_guard_init()`,
`conjoint_determine_status()` and `validate_conjoint_convergence()` are kept —
they have tests in `test_guard_fixes.R`.

**A2 — `setwd` unwinding.** The work order said to add `on.exit`. The `setwd`
sits inside a `withProgress()` expression in a Shiny observer, where `on.exit`
binds to an ambiguous frame; `tryCatch(..., finally = setwd(old_wd))` restores
the directory at exactly the right moment with no frame ambiguity. Same intent.
