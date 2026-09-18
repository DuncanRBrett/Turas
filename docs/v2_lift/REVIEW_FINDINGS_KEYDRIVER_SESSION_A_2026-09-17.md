# KeyDriver Session A. Independent pre-merge review

**Date:** 2026-09-17. **Reviewer:** a Fable session independent of the one that built the work, briefed by `REVIEW_BRIEF_KEYDRIVER_SESSION_A.md`.
**Branch:** `feature/keydriver-correctness` at `43ed4310`, 16 commits, not merged, not pushed. Reviewed in `/Users/duncan/Dev/Turas` (confirmed with `git rev-parse --show-toplevel`; the three other worktrees are on other branches).
**Specification:** `HANDOVER_KEYDRIVER_FOR_OPUS.md` sections 0 to 2 and `KEYDRIVER_PRODUCTION_REVIEW_2026-07-11.md`. The author's notes file was not opened until sections 1 to 7 below were written; section 8 records where it and this review disagree.
**Method:** per `V2_LIFT_PROGRAM.md` section 2. Two independent readers on separate concerns (test honesty; the features that had never produced a number, H6/H7/H8/H11 and the mediums), and a coordinator who kept the fixture, C1, C2, H4, H5, M6 and the shared loader, and re-ran every reader claim that carries weight before it went in.

Every number in this document comes from something this session ran or read. Each finding says which. Nothing was fixed.

---

## 0. Verdict

**PASS WITH FIXES.** Seven HIGH findings must be closed before merge; none is large.

The two CRITICALs are closed, and I verified both by execution in both directions, against implementations I wrote from the definitions. The relative-weights engine agrees with an independent Johnson (2000) computation to 1e-14 on the example data and the raw weights sum to the model R-squared exactly; the old engine on the same data sat up to 24.6 percentage points away and returned 50/50 on the two-driver case. Weighted dominance reconstructs the weighted R-squared to 6e-17 against a brute-force weighted LMG; the old sqrt(w) transform summed to 0.901 against an R-squared of 0.743. The segment layer is weighted, sees factor drivers and reads every Segments row. The mixed path refuses a singular matrix instead of substituting a proxy. NCA runs and classifies. The shared loader change is safe on every sourcing shape I could find in the repo and fixes the case that failed on main. The example fixture is right at its committed seed, and both configs run end to end to the answer the README states.

What keeps it from a clean PASS is the layer around the engine, and the fact that the suite does not reach it. SHAP for a categorical driver still produces nothing in production: the dummy map is now built, and passed to shapviz the wrong way round, so the failure moved rather than closed. The pre-flight checks now run, and two of them are wrong for real configs: one refuses a template-spelled quadrant config that runs clean when spelled "Yes", and one degrades any template-built mixed study with a false statement naming the deleted `partial_r2` engine. An unweighted mixed study with one numeric driver still dies with a bare error. An all-categorical study is refused with advice that names a setting that does not exist. The configured `random_seed` never reaches the bootstrap. Four disclosures the handover asked for (quadrant source, bootstrap policy, seed, "no interval for Shapley") are computed and written nowhere a reader can see them. And the pre-flight checks run only when the caller has sourced them, which the GUI does and the suite's one end-to-end test did not.

None of these is a wrong client-facing number under a PASS banner, which is what Session A existed to remove. All of them are the kind of thing the example was built to catch, and four of them (F3, F4, F5, F13) were found by running the example with one setting changed.

Counts: 0 CRITICAL, 7 HIGH, 12 MEDIUM, 10 LOW.

---

## 1. Suites, branch and loader (what I ran myself)

All from the repo root, this session, with a counting reporter (`as.data.frame(test_dir(...))`):

| Suite | Files | Tests | Expectations | Failed | Skipped | Warnings |
|---|---|---|---|---|---|---|
| keydriver | 27 | 395 | 1,202 | 0 | 2 | 2 |
| shared | 23 | 465 | 1,348 | 0 | 4 | 19 |
| catdriver (loads the shared library through a directory loop) | 8 | 227 | 676 | 0 | 1 | 2 |

The two keydriver skips are package-present skips (htmltools, glmnet installed); the two warnings are the same two the July baseline carried. The shared warnings are the minify size-ratio notes on tiny fixtures, none in the loader test. Reader B's own run of the keydriver suite: 1,198 passed, 0 failed, 2 skipped.

**Branch history (execution).** `git log main..HEAD` is 16 commits, all dated 2026-09-17, all authored DuncanRBrett. `git diff --name-only main..HEAD` touches only `modules/keydriver/`, `examples/keydriver/`, `docs/v2_lift/`, `modules/shared/lib/import_all.R` and `modules/shared/tests/testthat/test_import_all_self_location.R`. The three rescued commits (`ee4ed901`, `cb2fcb52`, `00772aca` on `steps/rescued-from-keydriver`) are not ancestors of HEAD (`git merge-base --is-ancestor`, each). The untangle is complete.

One thing the brief did not say: the branch was rebuilt from `6d0995db`, and main has since moved to `491d4829` (12 commits: the maxdiff follow-ups, the repair of 20 committed workbooks, the simulator callout fix). `git merge-tree --write-tree main HEAD` produces a tree with no conflicts, so the merge is clean, but the branch is not level with main (F16).

**Shared loader (execution).** Probes in fresh `Rscript --vanilla` processes against the branch's `import_all.R` and against main's copied to scratch beside the same library:

| Sourcing shape | main | branch |
|---|---|---|
| `source()` from the top of a script, cwd = repo root | loads | loads |
| `source()` inside nested functions, cwd = /tmp (the Shiny GUI case) | refuses IO_SHARED_LIB_NOT_FOUND | loads |
| brand/catdriver-style `for (f in list.files(lib)) source(f)`, cwd = /tmp | not run | loads, `capture_console_all` and `turas_saveWorkbook` present |
| `sys.source(..., envir = env)` from repo root (tabs `test_pricing_island.R` shape) | not run | loads |
| `sys.source()` from /tmp | not run | refuses (no `ofile` to find; the old fallback, unchanged) |
| `source(chdir = TRUE)` with a relative path | refuses | refuses (no caller in the repo uses this) |

Of the 43 R files that mention `import_all`, only the catdriver GUI, the keydriver GUI and the weighting runner and GUI `source()` it by name; every other module and test loads the shared directory by listing it, which is the third row. The catdriver and shared suites above are the execution evidence for the dependants. The `srcfile` branch of the new walker can never fire (F23); harmless.

---

## 2. Question 1: are the numbers right where they were wrong before?

### C1. Johnson's relative weights. CLOSED. Execution, both directions.

Independent implementation from the definition (`Lam = V sqrt(D) V'`, `beta* = Lam^-1 r_xy`, `rw = Lam^2 beta*^2`), plus a second symmetric-root route by Denman-Beavers iteration that does not use `eigen()`. On the Suiderland data with the study weight:

| Driver | old engine (main) | new engine | mine (eigen) | mine (Denman-Beavers) |
|---|---|---|---|---|
| digital_banking | 20.897 | 45.500 | 45.500 | 45.500 |
| fees_clarity | 20.395 | 21.267 | 21.267 | 21.267 |
| branch_service | 20.254 | 14.989 | 14.989 | 14.989 |
| staff_knowledge | 19.930 | 11.491 | 11.491 | 11.491 |
| product_range | 18.525 | 6.753 | 6.753 | 6.753 |

Max |new - mine| 1.1e-14 points. Raw weights sum to 0.742586, the weighted model R-squared, to six places. The old engine returned near-uniform shares on a study whose true effects run 0.80 to 0.05.

Handover case r12 = 0.5, r1y = 0.6, r2y = 0.2: mine 92.9 / 7.1 (raw 0.3467 / 0.0267, sum 0.3733, equal to the R-squared from the betas); old engine on data with exactly those moments 50.00 / 50.00; new engine 92.85 / 7.15.

Mixed path with `contact_channel`, weighted: new 38.54 / 20.40 / 13.96 / 10.98 / 6.43 / 9.70 equals my term-level Johnson on the weighted model-matrix correlations aggregated through `build_term_mapping`; raw sum 0.787179, the weighted mixed R-squared. Unweighted mixed: new equals mine to three decimals; raw sum 0.788306, the R-squared. Old mixed on the same data: 20.66 / 20.12 / 19.15 / 19.47 / 17.87 / 2.73.

Bootstrap site (`calculate_single_bootstrap`): read only, the same three lines, no rescale. Exercised end to end by the example (200 of 200 iterations); I did not recompute a replicate by hand.

### C2. Segment comparison. CLOSED on three of four counts; the fourth is met by refusal; one residual (F8).

- (b) categorical drivers, execution: `contact_channel` scores 22.46 in the Younger segment; the old engine on the same data scores it 0.00 in every segment.
- (c) every Segments row and `segment_values`, execution: the example's four rows on two variables produce `Younger_Pct`/`Older_Pct` on `age_band` and `Standard_Pct`/`Premium_Pct` on `customer_tier`; the old call split the first variable into its four raw bands and ignored the second.
- (d) failures degrade: reading `00_main.R` (the `kd_segment_failure` handler appends to `degraded_reasons`). A configured-but-absent segment variable is refused before that path is reached, by pre-flight check "Segment Variables" as `CFG_PREFLIGHT_FAILED` naming the variable (execution: a `region` row added to the example's Segments sheet). The handover allowed refuse or PARTIAL. See F20.
- (a) weighted per-segment models, execution: coefficients come from `lm(weights =)`. The standardisation is a hybrid; see F8.

### H3. Provenance. CLOSED. Execution.
The example workbook's Run_Status reads `primary_method = shapley_r2_decomposition`; the three v10.3 functions are gone from `03_analysis.R`; the stats-pack SHAP line names xgboost/shapviz; `partial_r2` has 0 hits in the generated HTML. The template, the docs and pre-flight check 5 still carry the withdrawn knob, and check 5 now asserts it as live; see F5.

### H4. Mixed-path singular fallback. CLOSED. Execution.
A mixed model with an exact duplicate driver: the old `calculate_relative_weights_mixed` printed one WARN line and returned 48.66 / 48.66 / 2.68 under the `Relative_Weight` name; the new one raises `MODEL_SINGULAR_MATRIX`, the same code as the non-mixed path.

### H5. Weighted dominance. CLOSED. Execution, both directions.

| Driver | old sqrt(w) transform | new closure | brute-force weighted LMG (mine) |
|---|---|---|---|
| digital_banking | 0.296061 | 0.339916 | 0.339916 |
| fees_clarity | 0.178439 | 0.156853 | 0.156853 |
| branch_service | 0.161997 | 0.110110 | 0.110110 |
| staff_knowledge | 0.143463 | 0.085244 | 0.085244 |
| product_range | 0.120948 | 0.050464 | 0.050464 |
| sum | 0.900908 | 0.742586 | 0.742586 |

Weighted full-model R-squared 0.742586; max |new - mine| 5.6e-17. The module's Shapley column on the same run (45.8 / 21.1 / 14.8 / 11.5 / 6.8) matches my weighted LMG shares (45.775 / 21.122 / 14.828 / 11.479 / 6.796), the identity the review said should hold and now does. Sixteen drivers: `PARTIAL`, the omitted driver named, 17 s for 2^15 submodels; the Dominance sheet carries "Weighting" and "Drivers omitted" rows (execution).

### H6. SHAP dummy collapse. NOT CLOSED in production. Execution (reader B, reproduced by me).
The pieces work: `encode_features` records the owner of each dummy, `create_feature_map` returns `GenderFemale -> Gender, GenderMale -> Gender`, and the fallback matches known levels exactly. The old regex on main really never matched (`grepl` FALSE on both dummy names). But `shap_calculate.R:210-216` passes that map to shapviz's `collapse`, and shapviz 0.10.3 wants the inverse shape, driver to dummies (its own help example is `list(Species = c("Speciessetosa", ...))`). Through the pipeline, the mixed example with `enable_shap = Yes` refuses `FEATURE_SHAP_FAILED: 'collapse' cannot have overlapping vectors.`; under `continue_with_flag` SHAP is dropped with a banner and `results$shap` is NULL. On main the same run failed with a different message. Reader B inverted the map (`split(names(map), unlist(map))`) and the path ran to driver-level importance x1 49.8%, x2 28.7%, Gender 21.5%. `test_shap_feature_map.R` never calls shapviz, which is why the suite is green. See F3.

### H7. NCA. CLOSED bar one table. Execution (reader B) against NCA 5.0.0.
Constructed data with a genuine ceiling: the necessary driver is classified "Necessary Condition" (effect 0.4775, p = 0.02, 50 replications), the unrelated one "Not Necessary" (0.0421, p = 0.627); `nca_test_reps = 0` gives "No significance test" with p NA; a constant column gives PARTIAL with `drivers_failed` named. The extraction matches the package's real return shape (`summaries` keyed by driver; params rows "Effect size", "p-value", "Ceiling accuracy", "Ceiling zone"; "Scope" in `$global`). The bottleneck table is wrong (F12).

### H8. Pre-flight wiring. WIRED when the caller sources it, and miscalibrated. Execution (reader B and reader A, the load-bearing cases reproduced by me).
With the validators loaded, the continuous example logs "All 14 pre-flight checks passed"; a Segments row on a missing variable refuses with the variable named. Then: check 13 reads `config$importance_source` where the live object has it under `config$settings` (F4); checks 12 and 13 fire only when the setting is spelled `TRUE` (the template's spelling) and never for `Yes`; check 5 polices the withdrawn `AggregationMethod` (F5); `check_shap_dependencies` emits Error when xgboost is absent whatever `shap_on_fail` says; and `segment_values` is parsed three different ways by three consumers (F15). Any Warning makes the run PARTIAL, and check 7 (n below 1.5 times the minimum), check 9 (a driver pair above 0.9) and check 5 (any template-built mixed study) will produce one on ordinary studies. And nothing in `R/` sources the validators, so a headless run skips all of it (F7).

### H11 / M2. Quadrant source. HALF. Execution (reader B, the stamp absence reproduced by me).
`importance_source = "shapley"` refuses `CFG_QUADRANT_IMPORTANCE_SOURCE` with the valid set and the migration hint; the template dropdown equals `KD_QUADRANT_IMPORTANCE_SOURCES`; the `shap` branch now reads `SHAP_Importance` first. The recorded source reaches no sheet and no HTML section (F10), and the `auto` path still prefers `Shapley_Value` over `SHAP_Importance` (F26).

### M1, M3, M4, M5, M6, M14
M1 done at the two `03_analysis.R` sites, not the segment site (F8). M3 applied but the setting is dead for the bootstrap and unrecorded (F6). M4 written to attributes nothing reads (F11). M5 fixed: `ggplot_build` shows per-panel intercepts (execution, reader B). M6 half fixed (F1). M14 fixed for every `enable_*` gate (`as_logical_setting("Y")`, `("Yes")`, `("T")`, `(" yes ")` all TRUE; no `isTRUE(as.logical(` gate left in `modules/keydriver/R`); two remain in the HTML builder and one in the stats-pack gate (F13, F24).

---

## 3. Question 2: are the new refusals calibrated?

| Refusal | Verified | Blocks a legitimate study? | Tells the analyst what to do? |
|---|---|---|---|
| near-singular mixed model, `MODEL_SINGULAR_MATRIX` | execution | No: the same data refused on the non-mixed path already; the alternative was a silently different number | Yes: names the level-count cause and the 0.9 rule |
| all-categorical correlation request, `DATA_NO_NUMERIC_DRIVERS` | execution, weighted and unweighted | **Yes.** Beta, relative weights and Shapley are all computable for it | **No.** "Switch the correlation column off" names a setting that does not exist (F2) |
| unweighted mixed study, exactly one numeric driver | execution | **Crashes** with a bare `'x' must be numeric`, no refusal (F1) | n/a |
| unrecognised quadrant source, `CFG_QUADRANT_IMPORTANCE_SOURCE` | execution | Only a config carrying the old template's `shapley` / `relative` / `beta`; the message maps each to its new value | Yes |
| pre-flight Error, `CFG_PREFLIGHT_FAILED` | execution | Check 13 refuses a template-spelled quadrant config with no StatedImportance sheet, which runs clean and produces the quadrant when spelled `Yes` (F4). Check 5 refuses an unknown `AggregationMethod`, a setting nothing reads (F5). A Segments typo stops the whole run, defensibly | Check 13's fix names the stale set "shapley, relative, beta, or shap"; the others name the field |
| pre-flight Warning makes the run PARTIAL | execution and reading | Check 5 blank column: every template-built mixed study goes PARTIAL with a false reason (F5). Check 7 and 9 on ordinary studies | The Run_Status reason is the check's message |
| segment variable absent | execution | as above | Yes |
| dominance past fifteen drivers, PARTIAL | execution | No: table produced, omission disclosed on the sheet | Yes |
| `CALC_RW_DOES_NOT_SUM_TO_R2` (new, not in the brief) | reading | Cannot fire on a real run: `02_validation.R:239` filters to complete cases before both the correlation matrix and the model | Yes |
| bootstrap refuses any factor driver, `DATA_INVALID` (pre-existing) | execution (mixed example) | A mixed study gets no intervals for its continuous drivers either | **No.** "Convert 'contact_channel' to numeric" is advice an analyst must not follow (F14) |

---

## 4. Question 3: is the new green earned?

Reader A ran the branch's tests against main's engine (main's `modules/keydriver` extracted to a scratch root, the branch's tests copied in): 389 tests, 1,134 expectations, 102 failed, 10 errors, 5 skipped, spread across every handover item. So the new tests are not vacuous. Reader A also recomputed every golden number in `test_relative_weights.R` from the definition, with a closed-form 2x2 derivation that uses no `eigen()` call: the two-driver raw weights are 26/75 and 2/75 (0.346667 and 0.026667, shares 92.857143 and 7.142857), the k = 3 goldens agree to 3.9e-11, and the old engine gives 50/50 and 34.0/32.7/33.3 on the same inputs, so the goldens could not have come from the code under test on main.

The dead-skip audit (reader A, execution and reading): all 70 distinct names inside `exists("...")` skip conditions across the keydriver tests resolve to a definition; every `skip_if_not_installed` names an installed package; the two `build_term_map` skips are fixed to `build_term_mapping` and now assert exact mappings. No test never runs under `test_dir` today. The latent version is F17.

What the green does not establish (details in F17 to F19):

- The tight A1 goldens are asserted against the test's own reference implementation, not the engine. The engine's output is pinned by bounds (more than 85, less than 15) and by one comparison to population shares at `tolerance = 0.06` (`test_relative_weights.R:91`), where driver 3 is 5.25 against 4.14. My own check and reader A's are the tight checks the suite lacks, and both say the engine is right. The mixed and bootstrap sites carry the corrected lines with no value test at either.
- Three new files run zero tests under `test_file` because they skip at file level when the engine is not already loaded (F17). Reproduced: `test_relative_weights.R`, `test_segment_comparison_fixes.R` and `test_keydriver_example.R` each report 0 tests in isolation; they run under `test_dir` only because earlier files source the engine into the global environment.
- The only end-to-end test ran without the pre-flight checks (F7): the banner "pre-flight cross-reference checks" appears 0 times in the suite log.
- Twelve tests pin source text rather than behaviour (F19). All fail on main, so they are not vacuous, but a comment rewrite fails them and a behavioural regression that keeps the strings passes them.
- `test_shap_feature_map.R` stops at the map; the only end-to-end SHAP test uses numeric drivers only, which is why F3 shipped green.

Observations of my own:

- `test_segment_comparison_fixes.R:162` ("validation names a segment variable the data does not have") asserts source text: it greps `02_validation.R` for `missing_segment_vars` and `00_main.R` for `degraded_reasons` within six lines of it. It runs nothing. The handover asked for "missing segment var → PARTIAL not PASS" as behaviour; the production behaviour is a pre-flight refusal, which this test would not notice either way.
- `test_shap_feature_map.R` tests the map and never calls shapviz or `run_shap_analysis`; the production path is broken while it passes (F3).
- `test_engine_mediums.R:40` ("one seed covers the whole run") calls the bootstrap with a config; the pipeline does not (F6).
- `test_import_all_self_location.R` case 4 asserts the GUI file contains the string "Nothing downstream can run without it", not that a failed load is fatal. Cases 1 to 3 run real subprocesses; case 3 is the one that fails on main (reproduced: main's copy refuses from a nested function in /tmp, the branch's loads).
- `test_keydriver_example.R` asserts the answer, not a captured value, and is the only end-to-end run in the suite. Its order assertion is right at the committed seed; see F9 for the margin.

---

## 5. Question 4: did anything that worked stop working?

- **Config loader.** `AggregationMethod` validation removed: a config with a valid value loads and prints a NOTE; one with an invalid value, which used to refuse at load, now loads and is refused by pre-flight check 5 instead (F5). Reading and execution.
- **Template and existing configs.** A config whose `importance_source` is `shapley`, `relative` or `beta` used to run silently on `auto`; it now refuses at quadrant time with the mapping in the message. Intended, but any live keydriver config written from the old template will refuse after merge until its cell is edited (F25). **A regression:** a config with `enable_quadrant = TRUE` (the template's spelling) and no StatedImportance sheet used to run, because pre-flight never ran; it now refuses (F4).
- **GUI.** `run_keydriver_gui.R` parses (`parse()` this session); its source list gains `lib/validation/preflight_validators.R`; a failed `import_all.R` is fatal instead of a WARN. Not launched: Shiny is Duncan's verification path.
- **Excel writer.** The Dominance sheet gains two rows, verified in the scratch workbook. Every sheet the old workbook had is still present (13 sheets). The workbook is reconciled (no dangling drawing relationships, checked by unzipping); see F21 for the console line that says otherwise.
- **Quadrant charts.** Present in both example runs; per-facet thresholds verified by reader B.
- **HTML report.** Both example runs write a 1.2 MB report carrying the importance numbers, the segment section, and no `partial_r2`; the only `NaN` strings are inside the embedded JavaScript polyfill. It carries neither the quadrant source nor the bootstrap policy (F10, F11).
- **Fixtures.** Rebuilding the example into scratch reproduces the three committed workbooks sheet for sheet (`all.equal` TRUE on every sheet). They have no dangling parts.

---

## 6. Findings

Findings are numbered F1 to F29 with their severity; every C, H, M or A identifier elsewhere in this document is the July review's or the handover's. "Execution" means run this session (by me, or by a reader and reproduced by me where marked); "reading" means the lines named were read.

### HIGH

> **Follow-up, 18 September 2026 (the session that wrote Session A).** All
> seven HIGHs are fixed on `feature/keydriver-correctness` in commit
> `3165cd73`, each reproduced before it was changed and each covered by a test
> that fails on the code as found. Twelve test blocks across three files fail
> or error before the fix, with no skips. Keydriver suite after: 402 tests,
> 1,275 passing, 0 failed, 0 errors, 2 skips, both pre-existing
> package-absence skips.
>
> Two corrections to the findings as written, both in the reviewer's favour
> rather than against:
>
> - F4 says checks 12 and 13 fire only for the spelling `TRUE`. Both now go
>   through one `.pf_logical()` helper, so check 12 is fixed by the same
>   change.
> - F5's fix text says "delete check 5". Done, and the orchestrator's banner,
>   which claimed "All 14 pre-flight checks passed", now counts from a
>   constant so it cannot outlive a deleted check. There are thirteen.
>
> One thing the fix went beyond the finding on: F1 was fixed at
> `calculate_correlations()` rather than at either caller, so the weighted and
> unweighted paths behave identically and no future caller can reintroduce it.
> That removed the `< 2` branch in `step_calculate_correlations()` as well.


**F1 (HIGH). M6 is half fixed: an unweighted mixed study with exactly one numeric driver still crashes with a bare error.** Execution. Through `run_keydriver_analysis_impl` on a scratch config (drivers `x1` continuous, `g` and `h` categorical, no weight) the run dies with `simpleError: 'x' must be numeric`. `step_calculate_correlations` (`00_main.R:251-292`) leaves `correlations` NULL when fewer than two drivers are numeric; `calculate_importance_mixed` (`03_analysis.R:558-580`) refuses only when there are fewer than one, then calls `calculate_correlations(data, config)` on the full driver list, and `stats::cor()` on a frame with a factor column errors. The weighted twin runs to PARTIAL because `weighted_cor()` now returns NA for a factor. The review's M6 named `< 2`; the fix guards `< 1`. Fix: recompute on the numeric drivers only, or make the guard match the caller's.

**F2 (HIGH). An all-categorical study is refused, and told to do something impossible.** Execution (weighted and unweighted) and reading. `DATA_NO_NUMERIC_DRIVERS` fires for any study whose drivers are all categorical, although beta, relative weights and Shapley are all defined for it and the mixed path computes them. The `how_to_fix` says "Switch the correlation column off for this study"; no setting does that (`grep -rn 'correlation_display|enable_correlation' modules/keydriver/R lib` finds one hit, an HTML display option). Before the branch this shape crashed, so it is not a regression, but a refusal that cannot be acted on is what the calibration question is about. Fix: correlation column NA for every driver and a named degraded reason, as the pipeline already does for a partly categorical study.

**F3 (HIGH). SHAP for a categorical driver still produces nothing (A6 not closed).** Execution, reader B, reproduced. Mixed example with `enable_shap = Yes`: `FEATURE_SHAP_FAILED: 'collapse' cannot have overlapping vectors.` under `refuse`; SHAP dropped, `results$shap` NULL, run PARTIAL under `continue_with_flag`. Cause: `shap_calculate.R:210-216` passes the dummy-to-driver map where shapviz's `collapse` takes driver-to-dummies. With the map inverted the path runs and yields finite driver-level importance for the factor. The suite is green because `test_shap_feature_map.R` stops at the map. Fix: invert the map at the call (`split(names(map), unlist(map))`) and add a test that runs `run_shap_analysis_internal` on a factor driver with shapviz present.

**F4 (HIGH). Pre-flight check 13 refuses a template-spelled quadrant config that runs clean.** Execution, reader B, reproduced. The continuous example with `enable_quadrant = TRUE` and the StatedImportance sheet removed refuses `CFG_PREFLIGHT_FAILED: [Quadrant Requirements] enable_quadrant is TRUE and importance_source is 'auto', but no StatedImportance data is provided`; the identical config spelled `Yes` runs PASS and writes Quadrant_Summary, Action_Table and Gap_Analysis. Two defects: `preflight_validators.R:837` reads `config$importance_source` at top level, NULL on the live object (the value sits in `config$settings`), so every run looks like `auto`; and the premise is false, because the quadrant's performance axis comes from driver means and never needed stated importance. Checks 12 and 13 also fire only for the spelling `TRUE` (`toupper(trimws(x)) == "TRUE"`, lines 793-794 and 831-832), the template's dropdown spelling, and never for `Yes`. The fix text names the stale set "shapley, relative, beta, or shap" (line 845). This is a regression for template users: pre-flight never ran before, so these configs completed. Fix: read `config$settings$importance_source`, drop the stated-importance premise or make it a Warning, use `as_logical_setting`, and update the set.

**F5 (HIGH). A3 is incomplete, and pre-flight check 5 now enforces the withdrawn setting with a false statement.** Execution and reading. `lib/generate_config_templates.R:587-591` still defines `AggregationMethod` with the dropdown `partial_r2, grouped_permutation, grouped_shapley` and a pre-filled `partial_r2` row at line 653; `docs/05_TECHNICAL_DOCS.md:507-514, 674, 1431` document the method and the deleted `calculate_importance_partial_r2()`; `docs/04_USER_MANUAL.md:575, 2325` list it. The handover said the validation "and its template/doc mentions" go. Worse, `preflight_validators.R:382-424` (check 5) still polices the column: the mixed example with a blank `AggregationMethod` column, which is what the template emits, runs PARTIAL with the Run_Status reason "Categorical driver 'contact_channel' has no AggregationMethod specified. Will default to 'partial_r2'." That sentence is false: nothing defaults to anything, the engine is deleted, and `01_config.R:734-745` prints a NOTE saying so on the same run. A value outside the old set refuses the run over a setting that decides nothing. Fix: delete check 5, the template column and the doc entries.

**F6 (HIGH). `random_seed` is dead for the bootstrap, and the seed is recorded nowhere.** Execution, reader B, reproduced. `00_main.R:703-711` calls `bootstrap_importance_ci()` without `config`, so `kd_apply_seed(list())` always applies the default 20260101: the continuous example with `random_seed = 2026` and with `random_seed = 1` produce identical `CI_Lower` columns (`all.equal` TRUE). `xgb.cv` in `shap_model.R:63-70` has no seed call; reader B's two unseeded `fit_shap_model` runs on the same data gave mean SHAP 0.71521 and 0.72788, and the pipeline's SHAP comes out identical between runs only because the Shapiro-subsample seeding at `00_main.R:597` happens to precede step 6. `grep -i seed 00_main.R 04_output.R`: nothing; Run_Status has eight fields and none is the seed; the HTML has 0 hits; the stats pack echoes the configured value the bootstrap did not use. The handover: "config-driven seed (random_seed, default recorded)". Fix: pass `config` to the bootstrap, seed `xgb.cv` explicitly, write the seed to Run_Status.

**F7 (HIGH). The pre-flight checks run only if the caller happened to source them.** Execution (reader A, reproduced) and reading. `00_main.R:518` runs the checks inside `if (exists("validate_keydriver_preflight", mode = "function"))`, and nothing in `modules/keydriver/R` sources `lib/validation/preflight_validators.R`; only `run_keydriver_gui.R:125` does. Every other step the pipeline needs it sources itself from `find_turas_root()` (`00_main.R:701-926`). So the GUI runs the checks and any headless call, which the example README offers as an equal path, skips them silently, with a `PASS` where the GUI would refuse (reader A's probe: `shap_on_fail = "maybe"` is PASS without the validators loaded and `CFG_PREFLIGHT_FAILED` with them). The suite's one end-to-end test is such a call: the pre-flight banner appears 0 times in the suite log, so A8's "integration test proving a preflight Error blocks the run" does not exist; the H8 additions in `test_preflight_validators.R:579-598` are source greps and `:621-651` calls the orchestrator directly. This is the H8 dead-code shape moved one level up. Fix: source the validators from `00_main.R` like every other step, and make the example test assert the banner.

### MEDIUM

**F8 (MEDIUM). The weighted segment comparison is still a hybrid: weighted coefficients, unweighted spreads.** Execution. `07_segment_comparison.R:594` computes `term_sd <- apply(mm, 2, stats::sd)` while `sd_y` uses `.kd_weighted_sd` when a weight is set. On the `customer_tier` split, where the weights vary within segment, the module's Premium shares equal a recomputation with weighted coefficients and unweighted term SDs to four decimals and differ from the fully weighted recomputation by up to 1.23 points (branch_service 14.287 vs 14.607; contact_channel 22.928 vs 21.697). The `age_band` split cannot show this because the weight is constant within each age segment, which is also why the example's segment test cannot catch it. The handover's M1 named this file as one of the three sites.

**F9 (MEDIUM). The fixture's margin between the two smallest drivers is thinner than the README claims.** Execution. `build_keydriver_data()` for seeds 2026 to 2045, unweighted and weighted, scored by my own Johnson, LMG and standardised betas: relative weights and betas recover the order in all 40 runs; LMG, which is what the Shapley column computes, swaps `staff_knowledge` and `product_range` in 3 of 40 (seed 2042 weighted; seed 2045 both). The smallest RW gap between them was 0.00016 in R-squared units. At the committed seed 2026 the gaps are 0.024 and 0.035 and every measure recovers the order, so the fixture and the test are right as committed. The README's "the gaps are wide enough that sampling noise cannot reorder them" is not true of the design at n = 900; it is true of this seed. Either widen the two smallest effects (0.16 / 0.05 is a 0.11 gap on a 0.74 R-squared) or say the order is guaranteed at the committed seed. For the record, 11.6% of outcomes sit on the ceiling of 10.

**F10 (MEDIUM). The quadrant source is recorded and then written nowhere.** Execution and reading. `extract_importance_scores()` sets `importance_source_requested` and `importance_source_used` as attributes on its return; after `create_quadrant_analysis` the data frame's attributes are names, row.names and class only; `q$config$importance_source` holds the requested value, not the used one; `grep importance_source_used` outside `quadrant_data_prep.R` finds nothing. No sheet of the example workbook contains the word "source" (every sheet read); the HTML has no hit. The handover's A9 asked for the sheet and the HTML stamp.

**F11 (MEDIUM). The bootstrap disclosure exists only as attributes nothing reads.** Execution and reading. `05_bootstrap.R:352-366` sets `bootstrap_policy`, `iterations_requested`, `iterations_used`, `iterations_dropped`; `grep` finds them nowhere else. The workbook has no Bootstrap sheet at all (13 sheets; the writer never had one), the HTML has 0 hits for "mean of the bootstrap" or "no interval", and the stats pack reads `config$settings$bootstrap_iterations %||% 1000` (`00_main.R:1157-1163`), not the count used. The commit says "an honest bootstrap sheet"; the reader of the deliverable sees what they saw before, and locked decision 5's "no interval available" stamp is invisible.

**F12 (MEDIUM). The NCA bottleneck table's headers do not describe its numbers.** Execution (reader B) and reading. `10_nca.R:169` sets `bottleneck_levels <- c(50, 75, 90)`; lines 178-181 call `nca_analysis(..., bottleneck.y = "percentage.range", steps = 3)`, which yields a y grid of 0, 33.3, 66.7, 100; the nearest-level lookup then fills `Y_50pct` and `Y_75pct` from the 66.7 row (observed 63.3, 63.3, 99.3). "NN" (no minimum needed) coerces to NA and reads like a failed driver. Fix: pass the levels themselves (`bottleneck.y = "percentile"` or a matching `steps`), and map "NN" to a value that says so.

**F13 (MEDIUM). `Generate_Stats_Pack = Yes` in the example config produces no stats pack.** Execution. The gate at `00_main.R:1029-1031` is `toupper(x) == "Y"`, so "Yes" is FALSE. Both example runs wrote two files each and no `_stats_pack.xlsx`; with "Y" reader B got one. This is the M14 defect class on the one gate the sweep did not touch, and the example ships a setting that silently does nothing.

**F14 (MEDIUM). The README states a false thing about bootstraps, and the run's advice for it is wrong.** Execution and reading. The mixed example degrades with `DATA_INVALID: Column 'contact_channel' is not numeric` from `05_bootstrap.R:182-190` (pre-existing), and the whole bootstrap is dropped, so the five continuous drivers lose their intervals too. The README explains this as "A bootstrap cannot resample a factor", which is not so: resampling rows is indifferent to column types and `lm` fits the factor in every replicate; the limitation is that this bootstrap's estimators are numeric-only. The degraded reason's `how_to_fix`, "Convert 'contact_channel' to numeric", is advice an analyst must not follow for a nominal driver, and the Run_Status reason cell carries the whole boxed refusal with embedded newlines. The behaviour is later-session territory; the wording is Session A's.

**F15 (MEDIUM). `segment_values` is parsed three ways by three consumers.** Execution (reader B) and reading. Pre-flight splits on "," only (`preflight_validators.R:689`), the quadrant segment builder on ",\\s*" (`quadrant_comparison.R:56`), the pipeline on "[;,|]" (`00_main.R:409`). With "18-24; 25-34" the pipeline builds Younger with n = 412, pre-flight warns that the values are not in the data and the run goes PARTIAL, and the quadrant logs "Segment 'Younger' has no observations". One parser, or one documented separator.

**F16 (MEDIUM). The branch is not level with main.** Execution. Merge base `6d0995db`; main at `491d4829`, 12 commits on. `git merge-tree` reports no conflicts. Nothing to fix on the branch; Duncan should merge knowing it.

**F17 (MEDIUM). Three new test files run zero tests in isolation, and the shape is invisible.** Execution. `test_relative_weights.R:19`, `test_segment_comparison_fixes.R:10` and `test_keydriver_example.R:16` carry a file-level `skip_if(!exists(...))`. Under `testthat::test_file()` each reports 0 tests, 0 skipped, 0 failed: a whole-file skip produces no rows, so nothing looks missing. They run under `test_dir` only because `test_config_template_roundtrip.R:89` and `test_core_importance.R:22-33` source the engine into `.GlobalEnv` first, alphabetically ahead of them. `test_recovery.R:11` uses `stopifnot`, which errors in isolation and is the honest shape. This is the section 5 dead-skip pattern one rename away from silently dropping the C1 tests. Fix: source the engine in the helper, or `stopifnot`.

**F18 (MEDIUM). The suite pins the corrected engine loosely.** Execution (reader A) and reading. Every 1e-9 golden in `test_relative_weights.R` is asserted against the file's own `johnson_reference` (lines 22-28); the engine's output is pinned by bounds (`:63-64`) and one `tolerance = 0.06` comparison (`:91`) whose actual gap on driver 3 is 5.25 against 4.14. The A1(ii) sum-to-R-squared test (`:67-76`) never calls the engine and passes on main; the engine's own `CALC_RW_DOES_NOT_SUM_TO_R2` check is never exercised. The mixed (`03_analysis.R:837-839`) and bootstrap (`05_bootstrap.R:472-474`) sites have no value test. Two independent computations this session say the engine is right at all three sites; the suite alone would not have told you.

**F19 (MEDIUM). Twelve tests assert source text, and four pass on main's engine.** Reading (reader A), the segment one reproduced by me. Source greps: M5 (`test_engine_mediums.R:154-162`), M1 count (`:110-115`), M3 files (`:57-67`), M14 gates (`:27-38`), H3 twice (`test_relative_weights.R:126-139`), H4 (`:174-178`), H5 (`test_dominance_weighting.R:59-68`), C2 validation (`test_segment_comparison_fixes.R:162-174`), H8 twice (`test_preflight_validators.R:579-598`), H11 dropdown (`test_quadrant_source.R:80-88`). Passing on main: `test_recovery.R:72-107` (weighted differs from unweighted, which the weighted `lm` already did before M1), `test_relative_weights.R:67-76` (F18), and the two un-skipped A11 tests (expected, the fix was a name). Three helpers (`test_engine_mediums.R:41, :95`, `test_relative_weights.R:111`) skip rather than fail when `kd_seed_value`, `weighted_sd` or `.kd_primary_method` is absent.

### LOW

**F20 (LOW). The missing-segment-variable degrade path is unreachable in production.** Execution and reading. Pre-flight check "Segment Variables" refuses first, so `02_validation.R:120-127` and the `missing_segment_vars` block in `00_main.R` only run when `validate_keydriver_preflight` is not loaded. The GUI now loads it. Harmless duplication.

**F21 (LOW). A false "shared library not loaded" line prints on every keydriver run.** Execution and reading. "[TRS WARNING] Saving without part reconciliation: modules/shared/lib/import_all.R is not loaded" sits in eight `else` branches of `write_keydriver_output()` (`04_output.R:93, 145, 174, 229, 269, 335, 416, 581`), most of them column-name and VIF fallbacks unrelated to the saver. Traced with `trace(cat)`: it fired while `exists("turas_excel_escape")` and `exists("turas_save_workbook_atomic")` were both TRUE, and the saved workbook has no dangling parts. Pre-existing on main (8 occurrences there); not Session A's, but it is a console lie of the kind CLAUDE.md forbids.

**F22 (LOW). Latent weight misalignment in the mixed beta path.** Reading. `03_analysis.R:667-670` takes `w_all[seq_len(nrow(mm))]` when the weight vector is longer than the model matrix, pairing the wrong weights with the wrong rows. Unreachable today because `02_validation.R:239` filters to complete cases first. `model$weights` or the `complete` mask is the right source.

**F23 (LOW). Dead branch in the loader walker.** Reading. `import_all.R:57-61` tests `is.list(sys.frame(i)$srcfile)`; `source()` stores a `srcfilecopy`, an environment, so the branch never fires.

**F24 (LOW). Two `html_show_*` gates still read `isTRUE(as.logical(val))`** (`lib/html_report/03b_page_components.R:208`, `03_page_builder.R:74`), so `Yes` hides the section. Execution (reader B). The handover's M14 list was the `00_main.R` sites; these are the same class.

**F25 (LOW). Old template values refuse after merge.** Reading. Live configs with `importance_source = shapley/relative/beta` will stop at the quadrant step with a mapping in the message. Intended; flagged so the regeneration pass expects it.

**F26 (LOW). The quadrant's `auto` path still prefers `Shapley_Value` over `SHAP_Importance`** (`quadrant_data_prep.R`, `select_best_importance`), so a SHAP-enabled study that leaves the source on `auto` still plots the regression decomposition. Reading (reader B). The `shap` branch is fixed; `auto` is where the template leaves it.

**F27 (LOW). `.kd_segment_definitions` cannot name a level containing a comma, semicolon or pipe.** Reading. Edge case; one line in the template reference.

**F28 (LOW). Five "'*' not meaningful for factors" warnings on every mixed run**, from `calculate_weighted_means` (`quadrant_data_prep.R:396-412`) on the categorical driver. Execution (reader B). Noise on the console the analyst is told to read.

**F29 (LOW). Loose ends in the tests.** Reading (reader A). `test_segment_comparison_fixes.R:7` cites a `test_segment_pipeline.R` that does not exist; `iterations_dropped` is never exercised above 0; the example sets `min_segment_n = 60` and nothing asserts it took effect; `test_v104_features.R:236-238` still says NCA classification is binary while the vocabulary now has "No significance test" and "Not analysed"; the loader test's `outer`/`inner` at `:58-62` are defined and never called, so the nesting tested is `wrapper -> load_it -> source`.

---

## 7. What I could not verify

- The Shiny GUI end to end. I parsed `run_keydriver_gui.R` and read the source-list and fatal-load changes; I did not launch it. Duncan's `launch_turas()` run is the verification.
- A bootstrap replicate by hand. The three changed lines in `calculate_single_bootstrap()` are the formula I verified numerically at the two other sites; the bootstrap ran end to end (200 of 200); I did not recompute one replicate independently.
- The other modules' GUIs under the new loader. Evidence is the catdriver and shared suites (0 failures) and the six sourcing-shape probes; the tabs, tracker, brand, confidence, conjoint, maxdiff, pricing, segment and weighting suites were not run this session.
- Reader B's `check_shap_dependencies` result (Error under both policies when xgboost is absent) was obtained by shadowing `requireNamespace`; I read the function (`preflight_validators.R:788-820`) and it never reads `shap_on_fail`, but I did not reproduce the shadowing run.
- Reader A's run of the branch tests against main's engine (102 failed, 10 errors) was not repeated by me; I reproduced the two claims from it that carry weight (the zero-test files and the absent pre-flight banner).
- Any real client project. Nothing on OneDrive was read or written.

## 8. Where the author's notes and this review disagree

`SESSION_A_NOTES_KEYDRIVER.md` was read after sections 1 to 7 were written. It was committed (`eea62365`) before the example (`cbbca1d7`), the loader fix and the untangle, so parts of it describe an earlier state of the branch. Taking it as written:

- **Stale, not wrong.** The "branch is contaminated" section names three commits (`8a497e3a`, `c20a98fd`, `d3926287`) that are no longer on the branch; section 1 above confirms the untangle. The suite figures (26 files, 389 tests, 1,168 passing) predate `test_keydriver_example.R`; mine are 27 / 395 / 1,202 expectations. "NOT executed: any end-to-end pipeline run" was true when written and is not true of the branch, whose example test runs the pipeline on both configs.
- **H6.** The notes list it as fixed. It is not fixed in production (F3): the map is right and shapviz is handed its inverse. The notes say shapviz was executed end to end; whatever was run, it was not `run_shap_analysis_internal` on a factor driver, which fails on the first call.
- **H8.** The notes say the checks run. They run when the caller has sourced them (F7), and two of them refuse or degrade clean template-built configs (F4, F5). The notes' own line that checks 12 to 14 read `config$enable_shap` was corrected for those three; check 13 reads `config$importance_source` the same wrong way and was not.
- **M6.** The notes describe the crash as "an all-categorical mixed model"; the review's M6 was "fewer than two numeric drivers". The all-categorical case now refuses (with unusable advice, F2); the one-numeric case still dies (F1).
- **M3.** The notes say two runs of one config now give the same intervals. They do, because the bootstrap always uses the default seed; the configured `random_seed` does not reach it (F6), and nothing records which seed was used.
- **M4.** The notes say the Shapley "no interval" stamp "is in the policy note instead". The policy note is an attribute no writer reads (F11), so the stamp is in neither the workbook nor the HTML.
- **M1.** "Took the correct figure, not the disclosed hybrid" holds at the two `03_analysis.R` sites. The segment site is a hybrid without a note (F8).
- **M14.** "All eleven are fixed" is true of the eleven named. The stats-pack gate (`== "Y"`), two `html_show_*` gates and pre-flight checks 12 and 13 (`== "TRUE"`) are the same defect and were not on the list (F13, F24, F4).
- **H5's measurement.** The notes quote the old transform at 0.825110 against a true 0.825140, a gap in the fifth decimal. On the Suiderland weights (1.9 and 0.6) the old transform sums to 0.9009 against 0.7426. The fix is the same either way; the old error was not small on real weights.
- **H11.** "A missing column records what was used instead" is true of the attribute and of nothing the client sees (F10).
- **A3.** The notes list `AggregationMethod` as withdrawn. The template still offers it and pre-flight check 5 enforces it with a false message (F5).
- **"Every fix ships with a test that was run against the code as found."** Reader A confirms this for most: 102 failures and 10 errors when the branch's tests meet main's engine. Four pass on both (F19).

Where the notes are right and worth keeping: the H7 account (three independent faults, package installed), the `segment_values` never-read finding, and the C2 decision to leave `results$segment_comparison` on the first variable for Session B.

## 9. On the locked decisions

One paragraph, as the brief allows. Decision 5 (no interval for Shapley) is right. The way it landed, as a sentence in an attribute nothing prints, means the deliverable neither shows an interval nor says there is none; until F11 is fixed the decision is invisible to the client.
