# KeyDriver Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-11. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/KEYDRIVER_PRODUCTION_REVIEW_2026-07-11.md` (the findings — every fix below references its IDs C1-C2, H1-H12, M1-M24, §5); (3) for Session C only, `modules/tabs/docs/V2_MIGRATION_PLAN.md` **plus the review doc's §6 Phase 3, which supersedes that plan's keydriver-specific lines** (`:41`, `:55`). Load the `fable-method` skill. Project CLAUDE.md rules apply (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the keydriver row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by the Fable review (Duncan may veto — review §8 lists his open calls; if he rules, his message wins):

1. **Relative Weights gets FIXED, not dropped** (review §8-2 default): genuine Johnson symmetric-square-root math in all three code paths, golden-tested. If Duncan vetoes toward dropping the column, delete it from importance/bootstrap/report instead — never ship the current math.
2. **The dead v10.3 engine is DELETED** (review §8-1 default): `calculate_importance_partial_r2`, `calculate_importance_permutation`, `calculate_importance_by_config` go, the `AggregationMethod` validation-without-effect goes from config/template/docs, and every provenance stamp states the method that actually ran.
3. **No classic-tabs integration for keydriver.** Nothing per-respondent exists to export; do not build an exporter, do not export fitted values/residuals (D5 territory).
4. **V2 route = frozen `TR.KD` island + own workspace view** (the tracking pattern), NOT `index_scores` pseudo-questions, NOT new row kinds. Supersedes `V2_MIGRATION_PLAN.md:41,55` for this module.
5. **Honest-sig in the v2 view:** importance never enters `TR.stats.sigLetters`. Bootstrap CI whiskers for Correlation/Beta/Relative_Weight only; Shapley stamped "no interval available" (review §8-3 default — extending the bootstrap to Shapley is deferred).
6. **Session split:** Session A = Phase 1 (engine correctness), Session B = Phase 2 (config/template/GUI/report/doc honesty), Session C = Phase 3 (v2 island + view, **gated** on programme work-item OPUS-0 + Duncan's green light). One branch per session: `feature/keydriver-correctness`, `feature/keydriver-config-and-report-fixes`, `feature/keydriver-v2-report`. Do not merge — Duncan merges after his eyeball.
7. **Fix the template problem on the LOADER side.** `modules/shared/template_styles.R` is used by nine other modules — do not change its layout. Adopt tracker's header-aware pattern (`modules/tracker/lib/tracker_config_loader.R:27-47`).

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run the pipeline against real project folders, never write into OneDrive.
- Suite command: `Rscript -e 'testthat::test_dir("modules/keydriver/tests/testthat", reporter = "summary")'`. Baseline as of 2026-07-11: **0 fail / 2 warn / 4 skip / 928 pass**. Run before your first change and after every fix.
- Every fix ships with a test that **fails on the old code**; write the failing test first where practical.
- Keep an implementation-notes log; conservative option + "Deviations" entry when an edge case forces a change; surface it in the final summary.
- TRS refusals only (no `stop()`); new errors console-visible via `cat` (H2 means the GUI's last line currently lies — until B2 lands, don't rely on `message()` visibility either).
- Packages: `NCA` is not installed in this renv (H7 was code-read, not executed). If a fix needs it, flag the renv addition to Duncan rather than installing silently. `shapviz`/`xgboost`/`glmnet`/`domir`/`mgcv` — verify with `requireNamespace` before claiming any of their paths verified end-to-end.
- When done: state plainly what was verified by execution and what was not. A Fable independent pre-merge review follows Session A — leave a clean trail, and do not share your working notes with it.

---

## 2. Session A — Phase 1: make the numbers honest (`feature/keydriver-correctness`)

Work in this order (file:line evidence for each is in the review doc):

**A1. Fix C1 — Johnson relative weights, all three sites.** In `R/03_analysis.R` (main ~:283-311, mixed ~:699-707) and `R/05_bootstrap.R:432-439`: replace the PCA orthogonalisation with the symmetric square root — `Lam <- vecs %*% diag(sqrt(vals),p,p) %*% t(vecs)`, `beta_star <- solve(Lam) %*% r_xy`, `rw_raw <- (Lam^2) %*% (beta_star^2)`. Drop the R²-rescale at `:308-311` (correct raw weights already sum to R² — assert that instead). In the mixed path, use **weighted** correlations when `weight_var` is set (`:676-677` currently plain `cor`; reuse `calculate_correlations`' weighted machinery on the model-matrix columns). Tests (write first): (i) 2-driver hand-computed case — with r₁₂=0.5, r₁y=.6, r₂y=.2 the old code returns 50/50, correct Johnson does not; assert against hand-derived values; (ii) raw weights sum to model R² before normalisation; (iii) k=3 golden case (values from an independent reference computation, recorded in the test with its derivation).

**A2. Fix C2 — segment comparison, all four defects.** In `R/07_segment_comparison.R` + call-site `00_main.R:635-663`: (a) weighted `lm` per segment when `weight_var` configured (pass it through — the function currently never sees config weights); (b) categorical drivers: aggregate factor-term betas per driver via the existing `build_term_mapping`, or exclude categoricals with an explicit per-driver note in the output — never emit the silent 0; (c) iterate **all** Segments rows, honouring `segment_values` groupings (build the filtered factor per row); (d) any segment failure/refusal appends to `degraded_reasons` → run status PARTIAL (kill the bare `tryCatch → NULL` at `00_main.R:653-656`); also stop `02_validation.R:116-117` silently dropping a configured-but-absent segment variable — refuse or PARTIAL with a named variable. Replace the hard-coded `min_segment_n = 30` (`00_main.R:651`) with a config setting defaulting 30. Tests: weighted vs unweighted segment divergence; factor driver present (assert non-zero, or explicit exclusion marker); multi-row Segments + values grouping; missing segment var → PARTIAL not PASS.

**A3. Fix H3 — provenance.** Delete the dead v10.3 engine (locked decision 2): `03_analysis.R:822-997`, the `AggregationMethod` load-time validation (`01_config.R:669-676`) and its template/doc mentions. `R/04_output.R:307`: `primary_method` derives from what ran (e.g. `"shapley_r2_decomposition"`; mixed path stamps its aggregation). Fix the stats pack's "SHAP Values (shapr package)" claim (`00_main.R:1012` → shapviz/xgboost TreeSHAP). Update any test that referenced the deleted functions (`test_v104_features.R` — check what it covers before deleting; if it tests the dead engines, the tests go with them, logged).

**A4. Fix H4 — mixed-path RW silent fallback.** `03_analysis.R:690-697`: refuse on near-singularity exactly like the non-mixed path (`:268-280`), same code `MODEL_SINGULAR_MATRIX`. If Duncan prefers degradation, PARTIAL + per-driver Method_Note — but the default is refuse-to-match.

**A5. Fix H5 — weighted dominance.** `R/11_dominance.R:100-114`: remove the √w pre-multiplication; pass weights into the fits properly (a wrapper closure carrying the weight column into `domir::domin`'s `reg`, or compute weighted R² per subset via `summary(lm(..., weights=w))$r.squared`). Delete the false "algebraically equivalent" comment. Disclose the >15-driver truncation (`:79-87`) in the output sheet, not just console. Test: weighted fixture where General_Dominance sums to the weighted full-model R² and matches `lm(weights=)` sub-model R²s.

**A6. Fix H6 — SHAP dummy-collapse regex.** `R/kda_shap/shap_calculate.R:134-144`: build `feature_map` from the known factor levels (exact `paste0("^", col, level, "$")` matches, or better — construct the map at encoding time from `colnames` of the dummy matrix, which are known exactly). Test: factor driver `Gender` with levels Female/Male → map collapses `GenderFemale/GenderMale`; assert non-NULL map and driver-level SHAP importance present. If shapviz/xgboost absent in renv, make it a conditional test and say so.

**A7. Fix H7 — NCA (SUSPECTED, verify first).** `R/10_nca.R:80-100`: if `NCA` is installable in this renv (ask Duncan; do not silently add), fix the call to `nca_analysis(data=d, x=drv, y=outcome_var, ceilings=..., test.rep=...)` with a config-driven `test.rep` default, verify the return-structure extraction against the real package, and make all-drivers-errored → PARTIAL, not PASS. If the package stays out of renv: the feature refuses honestly (`PKG_NCA_MISSING`) instead of producing "Not Necessary" for everything.

**A8. Fix H8 — wire the preflight validators.** Call `validate_keydriver_preflight` from `run_keydriver_analysis_impl` after data load; refuse on Severity=="Error" rows, warn+log otherwise. Fix checks 12-14's config paths (`config$enable_shap` → `config$settings$…`, `preflight_validators.R:784, 871, 885`). Add `lib/validation/` to the GUI source list (`run_keydriver_gui.R:116-125`). The existing 574 lines of tests finally test live code; add one integration test proving a preflight Error blocks the run.

**A9. Fix H11 + M2 — quadrant importance source.** One canonical value list in `R/kda_quadrant/quadrant_data_prep.R:55-108`; unrecognised values **refuse** naming the valid set; template dropdown (`lib/generate_config_templates.R:296-297`) and both docs align to it. In the `"shap"` branch check `SHAP_Importance` before `Shapley_Value`. Record the chosen source in the quadrant output structure + Excel sheet + HTML section stamp.

**A10. Engine mediums.** M1: weighted SDs in standardized-beta computation (all three sites) — or, minimum, a disclosed hybrid note in output; pick, log it. M3: config-driven seed (`random_seed`, default recorded) applied to bootstrap, `xgb.cv`, `cv.glmnet`, Shapiro subsample. M4: disclose in the bootstrap sheet that point estimates are bootstrap means under PPS-resample/unweighted-fit and differ from the headline column; count+report dropped near-singular iterations; stamp "no interval available" for Shapley (locked decision 5). M5: per-facet thresholds in `quadrant_comparison.R:146-156`. M6: refuse (not crash) when a mixed run has <2 numeric drivers and correlations are requested (`03_analysis.R:498-500` guard). M14: `as_logical_setting()` for every `enable_*` gate (`00_main.R:146-149, 571, 670, 691, 712, 733`); test that "Yes"/"Y" enables.

**A11. §5 test additions** not covered above: fix the dead-skip helper name ("build_term_map not found" — `test_bug_fixes.R:135`, `test_integration.R:499`; the real function is `build_term_mapping`) so those two tests actually run; recovery test (synthetic truth → Shapley/beta rank correlation); weighted-vs-unweighted divergence test for the importance table.

Definition of done for Session A: suite green with new tests in, every ID above fixed-with-test or logged as deliberately deferred, summary states what was executed vs not (NCA/shapviz paths in particular). Then Duncan regens + the **Fable independent pre-merge review** runs.

---

## 3. Session B — Phase 2: config/template/GUI/report honesty (`feature/keydriver-config-and-report-fixes`)

**B1. Fix H1 — template round-trip (top priority).** Loader-side (locked decision 7): give `R/01_config.R` a header-aware sheet reader modelled on `modules/tracker/lib/tracker_config_loader.R:27-47` (scan for the row whose first cell is `Setting` / `VariableName` / etc., re-read with `startRow`), applied to Settings, Variables, Segments, StatedImportance, CustomSlides, Insights. Keep accepting flat header-row-1 sheets (tests use them). **The round-trip test is the acceptance criterion:** `generate_keydriver_config_template()` → fill minimal valid values programmatically → `load_keydriver_config()` returns PASS-shaped config. Also test the committed `docs/templates/KeyDriver_Config_Template.xlsx` loads.

**B2. Fix H2 + M7 — GUI honesty.** `run_keydriver_gui.R:439-445`: inspect `captured$result` — `turas_refusal_result`/`turas_error_result` classes and `run_status` — and print "Analysis REFUSED — see message above" (+ `showNotification(type="error")`); surface PARTIAL as "completed with degraded outputs". M7: the HTML-report checkbox must not force-override config — reflect the config value into the checkbox on config load, or pass `NULL` when untouched; make the stats-pack checkbox authoritative in GUI runs. M8: one bootstrap-iterations default constant used by both the run (`00_main.R:585`) and the stats pack (`:981`); align the three doc sites to it.

**B3. Fix H9 + M9/M10 — plumb the config through.** Extend `html_config` (`00_main.R:807-813`) with `insights`, `custom_slides`, `variables`, `analysis_name`, logo/company keys, VIF thresholds; extend `shap_config` (`:1110-1121`) with `cv_nfold`, `early_stopping_rounds`. Insert the built `config_slides` into the Added Slides container (`03c_section_builders.R:1074-1206` — it is currently constructed and dropped). Fix the CustomSlides column names docs-vs-code (`image_path`, no `slide_order`). Delete or implement `effect_size_method`/`use_stated_importance` (recommend delete from docs). Tests: config with Insights + CustomSlides rows → generated HTML contains them.

**B4. Fix H10 — Save Report content loss.** In `kdSaveReportHTML` (or a real `kdSyncAllInsights`, `kd_utils.js:162-165`): before serialising, copy every `.kd-qual-md-editor`/`.kd-qual-img-store` `.value` into `textContent`. Test: JS-level round-trip (headless or jsdom-style if available; else a targeted R test asserting the sync code is present + a manual-verification note for Duncan's eyeball).

**B5. Fix H12 + the doc-drift batch.** DriverType documented as required, correct case, in USER_MANUAL (3 sites) + TEMPLATE_REFERENCE; `html_report` → `enable_html_report` (2 sites); M13: refuse when Settings sheet lacks Setting/Value columns; warn on unknown setting names against a whitelist; refuse duplicates (mirror tabs `config_utils.R:110-124`). M11: add the v10.4 + `html_show_*` settings to `build_keydriver_settings_def()`. M12: ship Segments/StatedImportance sheets empty (examples in help rows only). M15/M16: regenerate CODE_INVENTORY from the tree; delete the `examples/keydriver/demo_showcase/` references (or create a minimal real example — smaller is fine, invented is not); reconcile README/docs/01_README duplication; one version constant (kills the v1.0/10.3/10.4/11.0 spread). LOW quick wins while in each file (review §4), judgment on scope, log what you skip.

**B6. Report-layer mediums M17-M24.** M17: normalise the Total chip/column case. M18: first *rendered* section gets the active class. M19: skip NA rank columns in the bump chart. M20: label or facet the CI chart by method (no more silent first-method). M21: `<`-escape the pin JSON island write (`turas_pins.js:257-261` is SHARED — check its other consumers before changing; if risky, escape at the keydriver store-build site instead and log the shared-fix as a follow-up). M22: store qual commentary as plain text + escape-and-wrap at render; make print mirror cards. M23: capture all tables in a section (or assign `kd-diagnostics-table` where the capture expects it) so VIF exports. M24: delete `kd_pinned_views.js` + `kd_slide_export.js`, correct the four docs that claim them live.

**B7. Tests** for every B-item per ground rules; suite green; tabs suite untouched (nothing here crosses into tabs).

---

## 4. Session C — Phase 3: v2 island + view (GATED — `feature/keydriver-v2-report`)

Do not start until OPUS-0 (socket consolidation) is done and Duncan green-lights. Then build per review §6 Phase 3, which supersedes the migration plan's keydriver mechanics:

- **R side:** `TR.KD` island serializer modelled on `modules/tabs/lib/tracking_island.R` (346 LOC), injected via the orchestrator contribution pattern (`run_crosstabs.R:~799-820`). Content: importance (driver × method, with ranks, direction, per-method stamps), bootstrap CIs (three methods only), model fit + VIF + `{n, n_excluded, weighted, nEff}`, quadrant coords + thresholds, segment matrix + classifications. `nEff` from `modules/tabs/lib/weighting.R::calculate_effective_n` ONLY (replace the inline Kish at `00_main.R:962-966` while there). Disclosure: segment cells gated on the project's `significance_min_base`.
- **JS side:** one workspace view `27k_keydriver.js` (model on `27t_tracking.js`/`27d_diffs.js`; 500-900 LOC): importance bars + method picker + CI whiskers ("no interval available" stamp on Shapley), IPA quadrant SVG (spec from `06_quadrant_section.R:327-435` — do not port R-generated SVG), driver×segment heatmap, diagnostics drawer with the reliability-verdict banner pattern. Shell tab gate + hash route (`24_shell.js:27, 187-189` analogy); island shape-check in `d2.validate` (`20_data.js:132-135` analogy). Tab carries "report filters do not apply here".
- **Zero new row kinds; zero `classify_row_labels`/`forQuestion` arms.** Everything freezes; no microdata contribution.
- **Curated drop-list log (D1):** elastic net / NCA / dominance / GAM sheets, effect sizes, method-comparison detail stay Excel-only — log each against V2_MIGRATION_PLAN §7.
- Tests: R serialization (shape, method stamps, nEff source), JS model/view under a synthetic island; update `modules/tabs/docs/11_DATA_CENTRIC_REPORT_V2.md` with the island schema.

---

## 5. What NOT to do (any session)

- Do not change `modules/shared/template_styles.R` layout — nine other modules generate templates through it.
- Do not build a classic-tabs exporter or export per-respondent model artefacts (locked decision 3; D5).
- Do not implement keydriver as `index_scores` pseudo-questions or add keydriver row kinds to `classify_row_labels`/`forQuestion` (locked decision 4).
- Do not ship the current Relative Weights math under any label, and do not "fix" it by deleting the golden tests.
- Do not touch shared `turas_pins*.js` behaviour without checking its other consumers (tabs, catdriver, hub) — B6/M21 has the fallback.
- Do not modify anything in OneDrive or client deliverables; do not headless-run real projects.
- Do not claim NCA/shapviz/cmdstan-class paths verified end-to-end unless you executed them with the package present — say which were executed.
- Do not merge to main; do not push. Duncan merges after regen + eyeball.
