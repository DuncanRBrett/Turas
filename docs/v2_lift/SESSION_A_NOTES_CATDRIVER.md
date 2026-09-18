# CatDriver Session A — implementation notes

**Branch:** `feature/catdriver-correctness` (cut from main `46eb9a01`, 2026-09-18)
**Work order:** `docs/v2_lift/HANDOVER_CATDRIVER_FOR_OPUS.md` section 2, against
`docs/v2_lift/CATDRIVER_PRODUCTION_REVIEW_2026-07-11.md`.

## Baseline

Suite at session start, from the repo root:

    Rscript -e 'testthat::test_dir("modules/catdriver/tests/testthat", ...)'
    8 files / 227 tests / 673 passing / 0 failed / 0 errors / 2 warnings / 1 skip

The handover quotes July's 659 passing; the module has since picked up the
shared-loader fix from the keydriver sessions, which is the difference.

## Work items

| Item | State | Commit |
|------|-------|--------|
| A1 C3 refusal system | done, with a GUI-source-order test | `5b8147a6` |
| A2 C1 + H1 + H2 + M6 weights | done | `5e6cd04c` |
| A3 C2 subgroup comparison | in progress | |
| A4 H3 + H4 ordinal safety | not started | |
| A5 H5 + M1 bootstrap honesty | not started | |
| A6 H6 multinomial_mode amputation | not started | |
| A7 H11 + M5 provenance | not started | |
| A8 M2/M3/M4 engine mediums | not started | |
| A9 dead code + inventory + tests | not started | |

## What each fix was proved against

Every fix was watched failing on the code before it.

- **C3.** Sourcing in the GUI's order and its working directory, then raising
  any refusal, gave `BUG_INTERNAL_ERROR: report to the Turas development team`
  and an empty `how_to_fix`. Same for loading a broken config workbook. Ten
  test failures on the old code, none after.
- **C1.** On the session fixture with weights ~U(0.4, 2.2): chi-squares of
  +34.1, **-250.3** and **-258.7**, a negative total, therefore **0 per cent
  importance and p = 1 for every driver**, under PASS.
- **H2.** Multiplying every weight by four halves every standard error in the
  binary engine. Verified in both directions.

## Deviations and judgment calls

1. **quasibinomial rejected.** The handover suggested it for the weighted
   binary fit. Ran it: coefficients are identical, but the dispersion is
   estimated so standard errors move, and `logLik()`/`AIC()` return NA, which
   would remove McFadden R-squared and the LR test. The warning is muffled at
   the fit site instead, with the reason recorded in
   `cd_muffle_noninteger_successes()`.
2. **`model.frame()` cannot recover the fitted rows here.** It re-evaluates the
   model call in the FORMULA's environment; CatDriver builds its formulas in
   the caller, so the engine's local `fit_data` is not visible and the call
   fails with "object 'fit_data' not found". Rows come from the fit's own
   `na.action` instead (`cd_estimation_rows()`).
3. **Confusion-matrix row alignment** was already broken: the caller's full
   outcome column was crossed with predictions covering only the fitted rows,
   so any missing predictor value killed the run with "all arguments must have
   the same length". Fixed while fixing C1, since the same row set is involved.
4. **`confidence_level` default.** A config without it gave `qnorm(numeric(0))`
   and an unrelated data.frame error two functions later. It now falls back to
   `CATDRIVER_DEFAULTS$confidence_level`. Two lines, outside the work order,
   logged here.
5. **Rescale reporting threshold.** Weights are always normalised to mean 1,
   but only a raw mean more than 1e-3 away from 1 is reported as a rescale.
   Rim weights are computed to mean 1 and then rounded in the config workbook,
   so a tighter threshold would put every ordinary weighted run into PARTIAL
   with a reason that says nothing.
6. **Missing-weight imputation semantics, for Duncan.** A missing weight is set
   to 1 **before** normalisation, which is the old behaviour, preserved. Under
   expansion weights that means the respondent ends up with about 1/raw_mean,
   effectively no weight at all. Mean imputation would make the console note
   ("set to 1") true on the scale that matters. Not changed: it is a semantic
   choice, not a bug, and the counts are now reported either way.
7. **The surviving suite warning** is a raw `glm()` call inside a mapper test
   (`test_catdriver.R`, "weighted binary model produces valid results"), not
   the engine. The engine's copy of that warning is gone.
8. **`00_guard.R` was never listed in `CODE_INVENTORY.md`**, so deleting it
   needed no inventory correction. The inventory's other drift is A9's.
9. **H7 (template cannot load) appears already fixed on main.** `01_config.R`
   loads its sheets through `load_config_table_sheet()` with header-row
   discovery, and `test_config_template_roundtrip.R` exists. Session B should
   verify rather than rebuild.
10. **Kish n_eff** now comes from the platform's shared `effective_n.R`
    (OPUS-0) rather than a local copy of the same formula.

## Not done, not verified

- The Shiny GUI has not been executed end to end by this session.
- No report has been regenerated; Duncan does that through `launch_turas()`.
