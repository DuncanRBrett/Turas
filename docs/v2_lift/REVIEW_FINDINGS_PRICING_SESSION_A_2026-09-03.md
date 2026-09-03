# Pricing Session A: Independent Review Findings

**Date:** 2026-09-03. Reviewing session (Fable). It did not write the code under review. It did not read `SESSION_A_NOTES_PRICING.md` until section 4 below was written; section 7 records what the notes say against what was found.
**Scope:** local main at `34078b33`, the range `da7872c2..34078b33` (two code commits, `0510f99e` and `34078b33`), judged against `PRICING_PRODUCTION_REVIEW_2026-07-11.md` (C1 to C3, H1 to H8, M1 to M14, section 5), `HANDOVER_PRICING_FOR_OPUS.md` section 2 (A1 to A9) and `HANDOVER_PRICING_V2_FOR_OPUS.md` sections 1 to 3. The work is already merged to local main and unpushed.
**Verification:** everything marked verified below was read or executed in this session from the repo root with renv active. Old-code checks ran against a detached worktree of `3f85abb3` in the session scratchpad (removed afterwards). The Karoo example was run into the scratchpad, not into `examples/pricing/Output`; Duncan's own launcher output there was read, not rewritten. Nothing was run against a project folder and nothing was written into OneDrive. Anything not checked is labelled next to the claim. No code on main was changed.

---

## 0. Verdict: PASS with fixes

The three CRITICALs are fixed and the fixes were executed in both directions with a hand check each (section 2). The suite claim is true: my own run reproduces 997 passing expectations with 0 failed, 0 skipped and 0 errors, and 38 of the 39 new test blocks fail or error on the old engine. The Karoo example runs from a headless entry point, the classic HTML report still renders from the new result objects, the template regenerates byte-for-byte, and the stats-pack switch works from both the config and the GUI option.

Three things gate client use and should land before a weighted or Gabor-Granger study ships on this code:

1. **Long-format Gabor-Granger still has the H5 defect.** The binary-domain check runs only for wide data. A long-format ladder coded 1 = Yes, 2 = No maps the 2s to missing, refuses with `DATA_GG_UNEQUAL_BASES`, and the refusal's first suggested fix (`NO_AFTER_STOP`) then produces 100% purchase intent at every rung under a PASS banner. Observed by execution. F1.
2. **The client workbook's Summary sheet still prints the count of valid weights as "Effective Sample Size".** H7 was fixed in the stats pack only. All three Karoo workbooks I opened show 400.0 where the Kish figure is 331.8. F2.
3. **The NMS extension is broken on both paths, and one part of that is a Session A regression.** The template pre-fills `PI_Scale = 5`; the code now passes that scalar to the package, which wants a scale vector, so any template config with the purchase-intent columns filled fails. Without `PI_Scale`, the weighted and unweighted NMS paths disagree with each other on unit weights. F3.

None of these touches the headline VW, GG or monadic numbers on the Karoo example or on the fixtures. Below them are calibration questions on two new refusals (F4, F6), a disclosure defect in the stats pack (F5), and a list of smaller items. Section 6 says what turns this into a clean pass.

---

## 1. Suite runs, my own numbers

Command: `testthat::test_dir("modules/pricing/tests/testthat")` with the silent reporter, counts from `as.data.frame()` of the result, from the repo root.

| Tree | Files | Tests | Passing expectations | Failed | Skipped | Erroring tests | Warnings |
|---|---|---|---|---|---|---|---|
| main `34078b33` | 27 | 345 | 997 | 0 | 0 | 0 | 14 |

The claim in the commit message, the tracker row and the brief is 997 / 0 / 0 / 0 / 14. It matches.

The three new test files against the old engine (`3f85abb3` worktree, run from that directory with the main renv library, and `fit_vw_psm` and `.pricing_parse_list` confirmed absent so the old code was what ran):

| File | Test blocks | Blocks that fail or error on old code | Blocks that pass on old code |
|---|---|---|---|
| `test_config_honesty.R` | 16 | 16 | 0 |
| `test_engine_honesty.R` | 19 | 18 | 1 |
| `test_karoo_example.R` | 4 | 4 | 0 |

Totals on the old engine: 39 blocks, 16 passing expectations, 35 failed expectations, 21 erroring blocks, 1 skipped. The one block that passes on old code is "isotonic smoothing pools violators instead of raising them (M1)", four expectations. It tests `smooth_isotonic()` directly, and that function existed unchanged as dead code before Session A. It is a golden for the function, not a regression test; the pipeline-level M1 test in the same file does fail on old code (1 of 4 expectations pass there).

---

## 2. Fix-by-fix verification, both directions

Probe scripts and outputs were in the session scratchpad (`probes/adversarial.R`, `probes/nms_and_wdup.R`, `probes/more.R`, `probes/last.R`, `probes/karoo_run.R`, `out/*.log`, `out/karoo_*.rds`), which is session-specific and not retained; the numbers quoted here are what they printed. Karoo numbers are from my own headless runs of the committed example unless labelled as Duncan's launcher output.

### C1 / A2: weighted Van Westendorp
- Path: `fit_vw_psm()` (`R/03_van_westendorp.R:723-800`) builds `survey::svydesign(ids = ~1, weights = ~w)` and calls `psm_analysis_weighted()`; a package error is caught and refused as `MODEL_VW_WEIGHTED_FAILED` (`:785-797`), a non-positive or missing weight as `DATA_VW_WEIGHTS_INVALID` (`:754-763`). No fallback path exists in the function. Read.
- Hand check: 200 respondents, integer weights 1 to 3. The weighted curve's not-cheap value equals the hand-computed weighted share `sum(w * (cheap <= p)) / sum(w)` at p = 50, 60, 78.6 and 100 (0.2868, 0.4695, 0.7741, 0.9036 in all three of hand, weighted design, duplicated rows). The price points agree with the duplicated-rows run to within the package's own grid resolution: PMC 52.86 vs 52.76, OPP 79.39 vs 79.39, IDP 79.09 vs 79.09, PME 113.49 vs 113.50. The package's weighted ECDF (`calculate_weighted_ecdfs`, `survey::svycdf`) is the duplication estimator. Executed.
- Karoo, drop, n analysed 356: weighted PMC 61.48, OPP 89.74, IDP 93.86, PME 135.88 (`psm_analysis_weighted (survey design)`); unweighted 61.88, 89.29, 94.55, 136.43 (`psm_analysis (unweighted)`). Different, as the generator intends. Executed.
- Grossing-scale weights (mean about 1200) run through the weighted VW path unchanged, OPP 79.50 with mean-1 weights and with the same weights times 1000. The ECDF is scale-invariant, so no refusal is needed there. Executed.
- Refusal, not fallback: the suite's own test mocks a `psm_analysis_weighted` that stops and gets `MODEL_VW_WEIGHTED_FAILED` (suite run). My probes reached the same refusal through a real package error (the NMS argument mismatch, F3) and `DATA_VW_WEIGHTS_INVALID` through a zero weight. Executed.
- Old engine: only `psm_analysis()` was ever called (`git show 3f85abb3:modules/pricing/R/03_van_westendorp.R`, `psm_args` at the old `:516-534`). Read.

### C2 / A4: stop-early Gabor-Granger
- Karoo stop-early config refuses `DATA_GG_UNEQUAL_BASES` with the per-rung bases in the message. The imputed config passes: 476 cells imputed, bases 400 at every rung, `diagnostics$imputation` stamped, stats pack row `GG: stop_early_imputation` carries the sentence. Executed.
- Imputed curve vs the full ladder on Karoo (raw acceptance): 0.938 / 0.810 / 0.643 / 0.396 / 0.226 vs 0.939 / 0.856 / 0.732 / 0.491 / 0.320; the imputed optimum is R80, the full ladder's is R100. The gap is a fixture artefact: 71 of 400 respondents in the generator's noisy full ladder have a Yes above their first No, and the stop-early copy was cut from that ladder, so imputation codes those Yeses as No. In a real stop-early design no such Yes exists. On the noiseless fixture in `test_engine_honesty.R` the imputed curve equals the full curve to 1e-12 (suite run). Executed.
- `impute_gg_no_after_stop()` fills only above the first No; a leading NA and a respondent with no No are left alone (suite test, and read at `R/04_gabor_granger.R:231-242`).
- Old engine: `calculate_demand_curve()` dropped NAs per rung with no base check (old `:339`). The new C2 tests error on the old code because the functions do not exist. Executed (section 1).

### C3 / A3: the interval brackets the reported estimator
- `bootstrap_vw_confidence()` takes `validate` and `weights` from the headline call and every replicate goes through `fit_vw_psm()` (`R/03_van_westendorp.R:679-686`, `:861-864`). The `estimate` column is the headline point; `boot_mean` is its own column; the `policy` attribute names the estimator and the flag. Read.
- Karoo (Duncan's launcher workbook, `VW_Confidence_Intervals`): estimate 61.48 / 89.74 / 93.86 / 135.88 equals the headline; boot means 61.61 / 89.91 / 93.92 / 136.01; every point inside its interval; 300 of 300 replicates succeeded. Read from the workbook.
- The policy change (equal-probability resampling carrying weights, replacing weighted-probability resampling): 150 replicates each way on the Karoo weights. Standard errors PMC / OPP / IDP / PME: equal-probability 1.22 / 2.15 / 2.09 / 2.52; weighted-probability 1.15 / 1.93 / 2.06 / 2.23. The new policy's intervals are wider, not narrower, and its bootstrap means (61.58 / 89.97 / 94.11 / 136.01) sit closer to the headline (61.48 / 89.74 / 93.86 / 135.88) than the old policy's (60.87 / 90.17 / 92.69 / 134.74), which double-counts the weights. Executed.

### H3 / A3: monotonicity semantics
- `validate_flag <- !identical(behavior, "flag_only")` (`R/03_van_westendorp.R:529-530`). The package's own rule is strict (`validate_price_preferences` in pricesensitivitymeter 1.3.3 uses `>` on all three pairs; read from the installed namespace), and `check_vw_monotonicity()` now matches it (`R/02_validation.R:588-590`).
- Karoo, weighted: drop 61.48 / 89.74 / 93.86 / 135.88 (n analysed 356); flag_only 62.00 / 89.75 / 93.86 / 133.44 (n analysed 400, validate FALSE, psm counted 44 invalid but kept them); fix 61.59 / 90.00 / 93.96 / 135.93 (n analysed 387: 13 respondents whose sorted answers still tie are set aside by the package). The three behaviours now produce three different results, as they must. Executed.
- Ties on Karoo: 44 of 400 (11.0%) violate the strict rule, 32 (8.0%) violate the ordering, 12 (3.0%) are lost to ties alone on answers rounded to R5. Executed. Real respondents round more coarsely than a generator; the loss on a real dataset was not measured and no real pricing dataset exists to measure it on.

### H1 + H2 / A1: template names and separators
- Template-shaped configs load with lowercase keys populated; commas and semicolons both parse; `CFG_GG_PRICE_SEQUENCE` refuses words (suite tests, all failing or erroring on the old engine). The shipped `Pricing_Config_Template.xlsx` is identical, sheet by sheet and cell by cell, to a fresh regeneration from `lib/generate_config_templates.R` (nine sheets compared). Executed.
- Template defaults read from the shipped file: `VW_Monotonicity_Behavior = drop`, `GG_Stop_Early_Imputation = NONE`, `Generate_Stats_Pack = Y`, `Min_Sample = 30`, `PI_Scale = 5`. Read.

### H4, H5, H6 / A5: monadic and coding
- Karoo monadic, weighted: slope -0.0367, p 4e-13, optimum R80.30, `weighted_n` on `Mon_Observed_Data`, caveat present in `model_summary`. Executed. Grossing weights refuse `DATA_MONADIC_GROSSING_WEIGHTS`; 1/2 intent refuses `DATA_MONADIC_INTENT_NOT_BINARY` naming `ONE_TWO` (suite).
- GG wide: 1/2 data refuses `DATA_GG_NOT_BINARY` naming `ONE_TWO`; under `ONE_TWO` the golden 0.75 / 0.50 / 0.25 is reproduced (suite). Long format: not fixed, see F1.

### H7, H8, M2 / A6: stats pack and disclosure
- Stats pack (Duncan's launcher run): `Valid N 400`, `Effective N (Kish) 331.8`, `Weighted estimates: VW price points (survey design); GG demand (weighted means)`, `VW: estimator psm_analysis_weighted (survey design)`. Read. `calculate_effective_n` is the shared helper, sourced with the TRS files (`R/00_main.R:105-109`). Read.
- H8, both paths, executed: a config with no `Generate_Stats_Pack` row writes a pack; `Generate_Stats_Pack = N` headless writes none; the GUI option `FALSE` beats a config `Y` (step 10 absent from the console; an earlier pack at the same path made file existence uninformative, so the console line is the evidence); the GUI option `TRUE` beats a config `N` (pack written). The GUI checkbox defaults on (`run_pricing_gui.R:190`). Read.
- M2: the `MONOTONICITY VIOLATIONS` block renders on the Validation sheet with 44 / 11.0% / drop. Read from the workbook.

### M1, M14 / A7: smoothing and the band
- Pipeline default is isotonic; `purchase_intent_raw` kept; the GG band brackets the smoothed curve (suite, and the Karoo `GG_Confidence_Intervals` sheet). On Karoo the raw curve was already monotone so smoothing changed nothing. Executed.

### M6 to M11, M12 / A8
- Duplicate refuses, retired names refuse by name, unknown names warn (suite). Divider regex: every non-help row the cleaner drops from the shipped template's five settings sheets is a true divider (`FILE PATHS & PROJECT`, `WIDE FORMAT SETTINGS (use if Data_Format = wide)` and so on, 18 rows listed in `out/adversarial.log`). A synthetic all-caps setting with no underscore and a blank value (`ANCHOR`) is dropped; `Anchor`, `DK_CODES`, `N_TIERS`, `Verbose` survive. Executed. The template writes no such name, so the accepted risk is real only for hand-typed configs.
- M11: `[Example]` rows are filtered by both loaders (suite). M12: see section 3, GUI.
- M13: the three never-firing output blocks are gone from `R/06_output.R`; no other file outside `07_`, `08_`, `09_` references `wtp_distribution`, `competitive_scenarios` or `constrained_optimization` (grep over `R/`, `lib/`, the GUI). Read.

### A0 / A9: the Karoo example and the golden tests
- The four committed configs run headless through `run_pricing_analysis()`: both PASS (0 events), monadic PASS, stop-early refuses, imputed PASS. Executed.
- The truth bands are not falsified: six generator seeds (2026, 1, 7, 42, 99, 123) all land every point in band and pass both GG rung bounds. The PMC band's lower edge (60) is tight: observed PMC ran 60.66 to 61.63 across the six seeds. I cannot tell whether the band was set from the truth or from the output; it holds across seeds either way. Executed.

---

## 3. What else was executed

- **Headless entry point.** `source("modules/pricing/R/00_main.R")` from `/tmp` defines `run_pricing_analysis`, `pricing_refuse`, `run_monadic_analysis`, `load_pricing_config` and `calculate_effective_n`, and resolves the module directory. It also prints an `IO_SAVER_NOT_FOUND` warning box, because `R/01_config.R:35-58` looks for the shared saver by walking up from the working directory rather than from the module. Pre-existing block, newly visible now that headless sourcing works. F12.
- **GUI console capture.** The sink pattern in `run_pricing_gui.R:484-517` was reproduced outside Shiny with a pipeline that prints, emits a `message()`, then stops: the text before the crash and the message line both reach the output, the error is appended, and both sinks are back to depth 0 afterwards. Not executed inside a Shiny session.
- **Classic HTML report.** Rendered twice from the new result objects, the both-methods config (1.15 MB) and the monadic config (1.13 MB), plus Duncan's own launcher render. The VW confidence table shows the headline R89.74 next to the boot mean R89.91; every `NaN`, `undefined` and `Infinity` string in the file sits inside minified library JavaScript, none in rendered text. The report did not break.
- **Excel workbooks.** Duncan's launcher workbook and my three: 18 sheets on the both-methods run, the CI sheet with its new columns, the monotonicity block, `Segment_Comparison` with n 356 = 66 + 52 + 87 + 151, `Mon_Observed_Data` with `weighted_n`. Opened with openxlsx, not in Excel.
- **Duncan's uncommitted `examples/pricing/Karoo_Pricing_Config.xlsx`.** The only changes against the committed file are `Generate_HTML_Report` and `Generate_Simulator` set to TRUE and a blank `DK_Codes` read back as missing; all four sheet dimensions are intact (A1:B27, A1:B8, A1:B11, A1:B5). An Excel edit, not a loader round trip. Nothing to do.

---

## 4. Findings

Severity is about client-facing consequence. "Verified" means executed or read at the cited lines this session.

### F1. HIGH. Long-format Gabor-Granger keeps the H5 defect, and the new refusal steers the analyst into it
`R/02_validation.R:434-449` calls `validate_gg_binary_domain()` only inside `if (gg$data_format == "wide")`. `code_gg_response()` maps any numeric outside the declared domain to NA (`R/04_gabor_granger.R:399-402`) instead of refusing as `code_monadic_binary_intent()` does. Executed on a 120-respondent long ladder coded 1 = Yes, 2 = No with true acceptance 0.958 / 0.725 / 0.425 / 0.117: `validate_pricing_data()` passes; `run_gabor_granger()` refuses `DATA_GG_UNEQUAL_BASES` (bases 115 / 87 / 51 / 14) and its first fix line says to set `NO_AFTER_STOP`; with that set the run passes with purchase intent 1.00 at every rung. Text answers outside the recognised spellings (`Definitely` / `Nope`) give n 0 and NA demand at every rung with no refusal. Long format is a documented input (`USER_MANUAL.md` 4.3) and the template carries its three settings. Verified.
Fix: run the domain check for `response_column` in the long branch too, and make `code_gg_response()` refuse out-of-domain numerics and unrecognised text rather than return NA. Add the long-format 1/2 fixture to `test_engine_honesty.R`.

### F2. HIGH. The client workbook's Summary sheet prints the valid-weight count as "Effective Sample Size"
`R/06_output.R:135-142`: the label is `Effective Sample Size` and the value is `sprintf("%.1f", ws$n_valid)`. Duncan's launcher workbook and my three Karoo workbooks all show 400.0; the Kish figure on the same run is 331.8 (stats pack). This is the H7 defect in the deliverable a client sees; the July review cited the stats pack site only and the fix stopped there. Verified.
Fix: Kish from `calculate_effective_n()` on the clean data's weights, and a separate `Valid N` row. Small and certain, so it is done: commit `e8315e66` on `fix/pricing-review-a-followups`, off main at `0698ffd2`, unmerged and unpushed. It changes `R/06_output.R` only and adds `tests/testthat/test_review_followups.R`, which runs the weighted monadic Karoo config and reads the Summary sheet back. The test fails three ways on the unfixed writer (no Valid N row, the figure equals n, the label lacks Kish) and passes with the fix. Full pricing suite in that worktree: 346 tests, 1005 expectations, 0 failed, 0 skipped, 0 errors, 14 warnings. Executed.

### F3. HIGH. The NMS extension fails with the template's `PI_Scale`, and its weighted path is unverified and inconsistent
Three layers, kept apart because they have different owners.
(a) Regression, Session A. `fit_vw_psm()` now passes `pi_scale` to the package (`R/03_van_westendorp.R:537`, `:732`, `:775`). The package's `pi_scale` is a vector of scale points that must match `pi_calibrated` in length (`validate_nms_parameters`, read from the installed namespace); the template pre-fills `PI_Scale = 5`. With `pi_scale = 5` the weighted path refuses `MODEL_VW_WEIGHTED_FAILED` and the unweighted path dies with the package's raw `stop()`, "pi_scale and pi_calibrated must have the same length", which is not a TRS refusal. With `pi_scale = 5:1` the module's own `!is.na(pi_scale)` fails on a length-5 vector. The old code never passed `pi_scale`, so NMS ran on the package defaults. Verified.
(b) New and unverified. The weighted NMS path did not exist before. With unit weights on well-formed data the package's `psm_analysis_weighted()` gives reach 0.071 to 0.078 and revenue-optimal 9.86 where `psm_analysis()` gives reach 0.000 everywhere and revenue-optimal 3.56 (the lowest grid price); the two paths disagree while the four price points agree to 0.01. Through the module on a 200-respondent fixture: weighted trial/revenue optimal 67.39 / 261.19 vs duplicated-rows 21.89 / 21.89. Verified by execution; the cause was not diagnosed.
(c) Observation only. On this install (pricesensitivitymeter 1.3.3) the unweighted NMS returned reach 0.000 at every grid price on the package's own input shape. Whether that is a package defect or a calibration argument the module should be passing was not established. Nothing in the module's suite exercises NMS (`grep pi_cheap tests/` finds one `NULL`).
Fix: until a golden exists, refuse by name when `Col_PI_Cheap` is configured, on both paths, and stop passing `pi_scale`. If NMS is wanted, it needs its own fixture with a hand-computable trial curve and a unit-weights equality test.

### F4. MEDIUM, calibration. The 2% rung-base tolerance refuses ordinary full-presentation ladders, and the refusal's first fix is the wrong one for them
`check_gg_rung_bases()` (`R/04_gabor_granger.R:188-209`) allows a spread of three respondents or 2% of the largest base. Simulated full-presentation five-rung ladders with independent random item non-response, 200 runs each:

| Item non-response | n = 150 | n = 300 | n = 600 |
|---|---|---|---|
| 1% | 43 refused | 12 | 0 |
| 2% | 124 | 49 | 11 |
| 3% | 150 | 103 | 33 |
| 5% | 184 | 144 | 99 |

At 2% to 3% missingness on a 300-respondent ladder, one run in four to one in two refuses, and `how_to_fix` lists `NO_AFTER_STOP` before "check for accidental blanks". The root cause is structural: VW has a completeness exclusion (`R/02_validation.R:456-466`), GG has none, so GG item non-response has nowhere to go but the tolerance. Verified by simulation. The author flagged this doubt in the brief.
Options: a GG completeness exclusion (respondents missing any rung excluded and disclosed, the VW pattern), a configurable tolerance with the refusal text reordered so "blanks" comes first, or both. I would take the completeness exclusion with disclosure, because it makes the stop-early pattern (many rungs missing per respondent, in a staircase) and the non-response pattern (few rungs missing, scattered) distinguishable: the exclusion count tells the analyst which one they have.

### F5. MEDIUM. Under `drop` the stats pack says violation rate 0.0% while 44 respondents were excluded for violating
`run_van_westendorp()` recomputes violations on the data it receives (`R/03_van_westendorp.R:629-633`), which under `drop` is already cleaned, and it uses the non-strict rule (`<=`) while validation used the strict one. Duncan's stats pack Assumptions sheet reads `VW: violation_rate 0.0%`, `VW: intransitive_handling drop`, `VW: n_analysed 356`, `VW: n_complete 356`, and nothing on that sheet says 44 were set aside. Under `flag_only` on Karoo the same row would read 8.0% (32 order violators) while the package counted 44 invalid (11.0%). Two definitions of "violation" in one module, and the client-facing count lives only in the Results workbook's Validation sheet. Verified (Duncan's stats pack, my flag_only run object).
Fix: carry `validation$monotonicity_violations` into the VW diagnostics and the stats pack, and make the diagnostic rule strict.

### F6. MEDIUM, calibration. Under `NO_AFTER_STOP` the base check is skipped entirely
`R/04_gabor_granger.R:67-84`: the imputation branch never calls `check_gg_rung_bases()` on the imputed data. A stop-early ladder where 30 of 100 respondents also skipped the first rung ran to PASS with bases 70 / 98 / 98 / 98 and no console line; the first rung's demand is then survivors-only, the C2 mechanism. The bases are in `rung_bases` and in the stats pack row, so a careful reader can see it, but nothing says so. Verified.
Fix: re-run the check after imputation with a message that names item non-response rather than stop-early, or apply the F4 completeness exclusion before imputation.

### F7. MEDIUM. Hard-coded `$` and an em dash in the price ladder text
`R/11_price_ladder.R:428`, `:453`, `:463` format prices with a literal `$`; the note "Standard tier anchored to optimal price point ($100.99)" is on the `Price_Ladder` sheet of a rand study (my Karoo workbook). `:117` carries an em dash in a console warning. Session A fixed the same defect in the segment insights (`R/10_segmentation.R`) and touched this file for the tier parser. Pre-existing, in scope by the handover's em-dash rule and by parity with the segment fix. Verified.

### F8. LOW. A zero weight gets four different treatments
Validation excludes negative weights only (`R/02_validation.R:270-272`) and counts zeros in `n_zero`; the monadic engine drops zero-weight cases in its `valid` mask (`R/13_monadic.R:91`); GG keeps them at zero contribution; VW refuses the whole run with `DATA_VW_WEIGHTS_INVALID` (`R/03_van_westendorp.R:754`). Executed with one zero weight: validation passes with `n_excluded 0`, VW refuses. The refusal text is clear, so this is consistency rather than danger. Fix: exclude zero weights at validation with a warning line, which is one character and one message.

### F9. LOW. The `flag_only` weighted bootstrap emits one package warning per replicate
`psm_analysis_weighted(validate = FALSE)` warns "Some respondents have inconsistent price structures" on every call; with 20 bootstrap iterations the run raised 21 warnings. At the default 1000 iterations the GUI console would carry a thousand identical lines. Executed. Fix: muffle that one warning inside the bootstrap loop (the headline call can keep it).

### F10. LOW. `CFG_GG_IMPUTATION_ORDER` cannot fire
`.gg_order_derivable()` (`R/04_gabor_granger.R:214-218`) tests `is.numeric(price) && !any(is.na(price))`, and `prepare_gg_long_data()` has already coerced price with `as.numeric()` (`:354`). The refusal fires only if a price failed to parse, which is a different problem with a different message. Read. Either delete the refusal or make it test what the handover meant (an order column).

### F11. LOW. Disclosure gaps in the deliverables
- The monadic p-value caveat reaches the console and the stats pack but not `Mon_Model_Summary` in the client workbook, which shows `Price Coefficient p-value 0.000000` with nothing beside it. Verified (my Karoo monadic workbook).
- `GG_Confidence_Intervals` has `mean`, `se`, `ci_lower`, `ci_upper` and no column for the published smoothed curve, so a reader cannot check from the sheet that the band brackets it. Read from the workbook.
- The stats pack's `Price Points tested` is always "not applicable" and `Questions in Config` always 0: `R/00_main.R:736-739` reads `config$price_points`, `config$gabor_granger$price_points` and `config$van_westendorp$price_range`, none of which exist (the GG key is `price_sequence`). Pre-existing. Verified on Duncan's stats pack, which has five rungs.
- The shared writer's Declaration still carries em dashes, in the "Respondents Analysed" and "Weighting" rows on Duncan's stats pack. Out of scope per the brief, logged.

### F12. LOW. Headless sourcing prints a saver warning
See section 3. `R/01_config.R:35-58` should look for `turas_save_workbook_atomic.R` relative to the module directory the way `00_main.R` now finds the guard. Read and executed.

### F13. INFO. Test assertions weaker than they look
- "a weight of 2 equals duplicating the respondent" allows 2% where the curves are identical and only the intersection differs by grid resolution (my check: 0.2% or less). Tightening it to 0.5% would make it bite.
- `expect_equal(vw$diagnostics$n_analysed, vw$diagnostics$n_valid)` in the Karoo test is tautological under `drop`, since violators are removed before the engine sees them. It would catch a regression only under `fix` or `flag_only`.
- The `NO_AFTER_STOP` recovery test is exact only because its fixture has no noise; the Karoo test checks direction only, which the brief already says.
- The suite still opens every file with `skip_if(!exists(...))`. The count is 345 tests today; a sourcing failure would still convert the file to skips silently. The brief's rule of checking the count after any change to a sourced file stands.

### F14. INFO. M3 remains, and was never in Session A's scope
The monadic-only Karoo workbook's Executive_Summary says "Moderate agreement across methods (8-15% variation)" and "Two methods available for comparison" for a one-method run (review M3). M3 was not in the July handover's Session A list, and the v2 handover's decision 9 keeps generated prose out of the tab. Logged so nobody thinks it was fixed.

---

## 5. The author's own doubts, answered

- **Strict tie rule.** It is the package's rule; matching it is right. Karoo loses 12 of 400 (3.0%) to ties alone on R5-rounded answers; real answers round coarser, so the loss will be larger and was not measured. The default `drop` is the honest name for what the module always did. What is missing is the disclosure (F5), not the rule.
- **2% rung-base tolerance.** Measured; F4. It trips ordinary full-presentation ladders and the fix text points the wrong way first.
- **`NO_AFTER_STOP` on noisy ladders.** The Karoo optimum moves from R100 to R80 under imputation because the fixture's stop-early copy was cut from a noisy full ladder (71 of 400 have a Yes above their first No). That cannot happen in a real stop-early design, where the respondent is never asked past the first No. The rule is right for the data it is meant for; the Karoo comparison is not evidence against it.
- **Bootstrap policy.** Equal-probability resampling carrying weights gives wider intervals than the old weighted-probability resampling (OPP SE 2.15 vs 1.93) and bootstrap means closer to the headline. Not too narrow.
- **Grossing threshold of 5.** Only the monadic glm is scale-sensitive; VW and GG are scale-invariant and run unchanged under grossing weights. Since the code normalises to mean 1 anyway, the refusal is a "did you mean this" guard, not a correctness gate. A legitimate weight file with mean between 2 and 5 passes and is normalised. Defensible as is.
- **Divider regex.** Every dropped template row is a true divider; the risk is confined to a hand-typed all-caps name with no underscore and a blank value. Acceptable, and the unknown-name warning would not catch it because the row is gone before the check. Worth one sentence in the manual.
- **Stats-pack default.** Both paths verified both ways (section 2, H8).

---

## 6. What turns this into a clean pass

1. F1: long-format domain check and a refusing coder, with the long 1/2 fixture as a test. Needs a decision on text handling (refuse unrecognised spellings, as the wide check does).
2. F2: done on `fix/pricing-review-a-followups` (`e8315e66`), one file plus one test. Duncan merges after reading it; the follow-up session for the rest can build on that branch.
3. F3: refuse NMS by name on both paths until it has a golden; stop passing `pi_scale`. If NMS is wanted, that is its own small session.
4. F4 and F6 together: Duncan chooses between a GG completeness exclusion and a configurable tolerance; either way reorder the refusal text so blanks come first.
5. F5: carry the validation violation count into the VW diagnostics and stats pack; make the diagnostic rule strict.
6. F7 to F12 are a few lines each and belong in the same follow-up commit.

Then Duncan's eyeball on the regenerated Karoo workbook, with the Summary sheet's Effective Sample Size and the Price_Ladder currency as the two lines to look at.

---

## 7. Against `SESSION_A_NOTES_PRICING.md`

Read after sections 0 to 6 were written, and treated as a set of claims.

Confirmed by this review: the suite figure (997 / 0 / 0 / 0 / 14); the ties finding, including the twelve Karoo respondents lost to ties alone; the `validate = FALSE` counting (psm reports 44 invalid on Karoo and keeps them, n analysed 400); the monadic re-source fix (headless sourcing from another directory works); the stats pack Declaration now saying weighted; the segment insight currency; the four advisor catches in the follow-up commit (monadic exact coding, the export settings refusing, the checkbox default, the monadic bootstrap policy); the resampling policy and its rationale, which my SE comparison supports; the em-dash claim for touched strings.

Claims the review qualifies:
- "Declared-binary columns validated on both engines." True for the Gabor-Granger wide path and for monadic; not for the Gabor-Granger long path (F1). The notes' deviation entry on long format concerns only the imputation order and does not mention coding.
- "`PI_Scale` wired to psm" (A8, M9). The wiring is the F3(a) regression: the template's value is a scalar and the package wants a scale vector. The old code's silence on `pi_scale` was the working state.
- "`NO_AFTER_STOP` on long-format data refuses otherwise (`CFG_GG_IMPUTATION_ORDER`)." The refusal cannot fire after the `as.numeric()` coercion (F10).
- "Stats pack Effective N (Kish), Valid N separate." True of the stats pack; the Results workbook's Summary sheet was not changed and still carries the H7 defect (F2).

The notes' "Not verified" list is accurate and this review covered two of its three items: the Excel deliverable and the classic HTML report were opened here (section 3) and neither broke. The GUI remains unexecuted by anyone but Duncan.

Nothing in the notes contradicts what was observed. The gaps are omissions of scope (long format, the Summary sheet), not misstatements.

---

## 8. What I could not verify

- The GUI inside a Shiny session. The sink pattern was reproduced outside Shiny only.
- The workbooks in Excel itself; they were read with openxlsx.
- Tie loss on a real dataset; none exists for pricing.
- The pricesensitivitymeter NMS internals; F3(c) is an observation on this install, not a diagnosis.
- `Segment_Column` beyond the Karoo run, which has four segments and one total.
- Whether the launcher's sourcing order (`run_pricing_gui.R:133`, its own file list, then `script_dir_override`) interacts with the new self-sourcing in `00_main.R` beyond double-sourcing; Duncan's launcher run completed, which is the only evidence.
