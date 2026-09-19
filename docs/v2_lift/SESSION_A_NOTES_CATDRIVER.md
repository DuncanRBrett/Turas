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
| A1 C3 refusal system | done | `5b8147a6` |
| A2 C1 + H1 + H2 + M6 weights | done | `5e6cd04c`, follow-ups `eee0ea2b` |
| A3 C2 subgroup comparison | done | `88f08dea` |
| A4 H3 + H4 ordinal safety | done | `fa993b39` |
| A5 H5 + M1 bootstrap honesty | done | `62f79330` |
| A6 H6 multinomial_mode amputation | done | `6455003f` |
| A7 H11 + M5 provenance | done | `938aeddc` |
| A8 M2 + M3 + M4 engine mediums | done | `e7d50246` |
| A9 dead code, inventory, pipeline test | done | `86efc4e5` |

Suite through the session: 227 tests / 673 passing at the start, **278 / 919 /
0 failed / 1 skip** at the end. Shared suite after the callout edit: 469 / 1,330
/ 0. Both run from the repo root.

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

## Deviations and judgment calls, second half

11. **CALC_ was missing from the module's TRS prefix list**, so a CALC_ code was
    rewritten to CFG_CALC_ and pointed the user at their configuration for a
    computation that had failed. Added, matching the project CLAUDE.md.
12. **A reserved-column guard was added** (`..catdriver_wt..`, `.wt`). The
    engines write those names into their own fit frames, and the importance
    refits decide whether a run is weighted by looking for one, so a user column
    of either name could make an unweighted run behave as weighted.
13. **`target_outcome_level` left over in a config prints an INFO line, not a
    degraded reason.** The setting changes no number now that one_vs_all is
    refused; it is dead, and the line says so. If a reviewer wants it as a
    PARTIAL, that is a one-line change.
14. **H4 was checked against a working ordinal project before it shipped.** The
    demo's ordinal config carries an Order and runs PARTIAL as it always did, so
    the new refusal does not break configs that were already right.
15. **`ordinal::nominal_test` needed its data in the call by value.** It refits
    per predictor with update(), which re-evaluates the call in the FORMULA's
    environment, and CatDriver builds its formulas in the caller. Without that
    the refits came back blank and the test would have reported "the assumption
    holds" having tested nothing. Same root cause as deviation 2.
16. **The dead JS pair stays.** Locked decision 7 lists `cd_pinned_views.js` and
    `cd_slide_export.js` for deletion, but the HTML startup guard
    (`99_html_report_main.R`) requires both files, so deleting them here would
    break every report until Session B fixes that list. Session B owns them,
    with `generate_catdriver_comparison_report`.
17. **Two dead-twin tests were retargeted rather than deleted.** The
    `missing_as_level` and `error_if_missing` tests ran against
    `prepare_analysis_data`; they run against `handle_missing_data` now, which
    is what production calls. The live handler labels the level
    "Missing / Not answered", not "Missing", which is what the dead twin used.
18. **`n_excluded` is original minus analysed.** The stats pack receives
    `prep_data$data`, which is already post-deletion, so counting from its own
    row count would always give zero. The original count comes from the
    diagnostics.
19. **One of my own tests removed the shared stats pack writer from the global
    environment** and left the next file skipping rather than failing, which
    reads as success. It saves and restores now. That is the same trap the
    keydriver review recorded as F19.
20. **Placeholder em dashes in output strings became en dashes**, per the house
    convention the tabs module set. The stats pack's "No events, ran cleanly"
    string lost its em dash entirely.

## The pipeline test was checked for discrimination

`test_pipeline_end_to_end.R` was written after the fixes, so it could not be
watched failing on main the way the others were. It was checked another way: the
column contract in `normalise_or_frame()` was temporarily reverted to the names
the pre-fix consumer read, and the pipeline test failed at
`expect_false(is.null(cmp))` with the comparison back to NULL. The file was
restored from HEAD immediately afterwards. The test discriminates.

## What a reviewer should look at hardest

- `05_importance.R`: the restructured `calculate_importance()`. A TRS refusal is
  an error condition, so anything raised under a `tryCatch(error = ...)` fallback
  becomes a fallback rather than a refusal. That was true of the whole importance
  path and is the kind of thing that can come back.
- `04b_multinomial.R` and `05_importance.R` together: the estimation frame and
  its weights now travel from the fit to the refits. If either side moves, the
  C1 defect returns silently.
- `cd_estimation_rows()`: three separate places used to assume predictions and
  the caller's frame had the same rows.
- The EPP change flips three of the demo's subgroups into a low-EPP stability
  flag. That is the gate working, not a regression.

## Not done, not verified

- **The Shiny GUI has not been executed end to end by this session.** The
  pipeline is exercised by `test_pipeline_end_to_end.R` and by demo runs from a
  script, both sourcing the files in the GUI's own order, but nobody has clicked
  through `launch_turas()`.
- No report was regenerated and no client project was touched.
- The one surviving suite warning is a raw `glm()` call inside a mapper test
  (`test_catdriver.R`, "weighted binary model produces valid results"), not the
  engine.
- Session B items met in passing and left alone: the HTML startup guard's file
  list, the unified report's blank Overview, the OR narration ("more likely"),
  `Generate_Stats_Pack` always-on, the loader's unrecognised-setting silence.

## After the independent review, 2026-09-19

The review (`REVIEW_FINDINGS_CATDRIVER_SESSION_A_2026-09-19.md`) returned PASS
WITH FIXES: 2 CRITICAL, 3 HIGH, 16 MEDIUM, 9 LOW. All 30 findings are now
closed on this branch, in three commits: `87db7f82` (F1 to F5), `b3a89f24`
(F6 to F30), and this one.

Suite 298 tests / 1,018 passing / 0 failed / 1 skip, from 287 / 968 before the
review fixes and 227 / 673 at the start of the session. Shared 469 / 1,330 / 0.

Three things the review found that were mine, and worth remembering:

1. **I stamped the ordinal importance as likelihood-ratio having checked glm
   only.** `car::Anova` on a clm returns a Wald chi-square, column "Chisq", 120.4
   where the LR figure is 135.4. The label is now read from the column the test
   returned, so it cannot drift again. This was the exact failure the stamp
   exists to prevent.
2. **The subgroup comparison keyed on driver and level**, which is right for a
   binary or ordinal outcome and wrong for a multinomial one, where each driver
   level carries K-1 odds ratios. Main shipped nothing there because the feature
   was dead, so the branch was the first to ship a WRONG table rather than none.
3. **The ordinal probability lift was never a lift.** `predict()` on a clm with
   no newdata returns each respondent's probability of their own observed
   category. The numbers were the same on main; what I added was a label and a
   client-facing callout that made them read as defined.

Two defects found while verifying the fixes, neither in the review:

- A positional column rename in the Subgroup Model Fit sheet gave a column the
  name NA as soon as the frame gained one. openxlsx then wrote a workbook whose
  shared-string table was empty: Excel would have offered to repair it and
  reading it back segfaulted R. **Every subgroup workbook written during the fix
  session was affected**, and nothing warned. There is now a test that reads
  back every sheet of a subgroup workbook and checks the string table against
  its own declared count.
- A PARTIAL with no affected output is refused by the shared run state. A
  stability flag was recorded as a degraded reason with nothing beside it, which
  was unreachable until the events-per-parameter fix made the flag fire; then an
  ordinary multinomial run died and wrote no workbook at all.

Both are the same lesson as the rest of this programme: the failure was not in
the statistics, it was in the layer around them, and only running the thing
end to end found it.

## Still open after the review

- The GUI has still never been run end to end by any session.
- F31: every expansion-weighted run is PARTIAL for the rescale alone. That is
  locked decision 4 working as designed, not a defect.
- F32: `test_golden_fixtures.R` fits its models directly rather than through the
  module, so it cannot catch a module regression, and `golden_expected.rds` is
  read by nothing. Left alone: rebuilding the goldens is its own piece of work.
- F33: the GUI still tests `run_status == "REFUSED"` while the handler returns
  `"REFUSE"`, so a refusal reads as success there. Session B owns it, and until
  it lands the C3 repair only reaches someone running from R.
