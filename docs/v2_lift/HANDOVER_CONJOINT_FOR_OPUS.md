# Conjoint Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-11. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/CONJOINT_PRODUCTION_REVIEW_2026-07-11.md` (the findings — every fix below references its IDs C1-C3, H1-H12, M1-M11, P1-P8, §5); (3) for Session C only, `modules/tabs/docs/V2_MIGRATION_PLAN.md`. Load the `fable-method` skill. Project CLAUDE.md rules apply throughout (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the conjoint row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by the Fable review (Duncan may veto; if he does, the vetoing message wins):

1. **Curated content bar** for the v2 report, not parity (standing decision D1). Decision-grade content migrates; diagnostics stay in the Excel deliverable. Log every capability left behind against V2_MIGRATION_PLAN §7's drop-list (it already names conjoint's individual HB utilities, CIs and MCMC diagnostics as Excel-only).
2. **Simulator stays out of the v2 report** (standing decision D2, conjoint reading): the simulator is *embedded* in the classic combined report (the "standalone" `lib/html_simulator` is a deprecated forwarder + dead files — review §0). The classic combined report+simulator survives as the linked simulator deliverable; the v2 report links to it. Do not re-split the simulator out and do not embed per-respondent betas in any v2 island.
3. **BW "simultaneous" refuses** (`CALC_BW_SIMULTANEOUS_UNIMPLEMENTED`-class TRS refusal naming `bw_method = "sequential"` as the fix) rather than getting a proper joint implementation now. Sequential stays the default and is statistically fine (review C2).
4. **HB/LC uncertainty gets fixed properly:** posterior SE of the population mean computed from bayesm's mixture-mean draws (`nmix$compdraw`), with the between-respondent SD kept as a separate, honestly-labelled "Heterogeneity (SD)" column. sd/√n is acceptable only if the compdraw route proves impractical — log it as a deviation if so.
5. **Honest-sig for the tabs export (D5):** export is allowed only from genuine respondent-level estimates — `method ∈ {hierarchical_bayes, latent_class}`, method stamped on the METHOD sheet and in QuestionText. Under `auto`/`mlogit`/`clogit` the exporter refuses (there is no respondent-level data; the refusal message says exactly that and how to enable HB). No override flag is needed (unlike maxdiff — conjoint has no approximate fallback to override for).
6. **Flagship tabs payload = per-respondent attribute-importance shares** (Allocation, sums to 100). Per-level part-worth Numeric columns are **deferred** pending Duncan's ruling (review §8.2) — build the exporter so they can be added, don't ship them in v1.
7. **Dead surface gets deleted, not wired:** optimizer config section (template + validator rows), `lib/html_simulator` dead files (keep only the forwarder), dead JS (`conjoint_charts.js`, unused export functions, `renderRevenueSummary`, `renderDemandCurve`), `predict_shares_with_ci`. Rationale: none has a caller or a test; wiring them is scope creep. Log each deletion.
8. **Session split:** Session A = Phase 1 (engine + config correctness), Session B = Phases 2+3 (report fixes + tabs exporter), Session C = Phase 4 (v2 migration, **gated** on programme work-item OPUS-0). One feature branch per session: `feature/conjoint-correctness`, `feature/conjoint-report-fixes-and-tabs-export`, `feature/conjoint-v2-report`. Do not merge — Duncan merges after his eyeball.

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run the full pipeline against real project folders, never write into OneDrive.
- Suite command: `Rscript -e 'testthat::test_dir("modules/conjoint/tests/testthat", reporter = "summary")'`. Baseline 2026-07-11: **0 fail / 12 skip / 2 warnings** — and note the 12 skips are themselves findings (§5): after A1 lands, the skip count must DROP. Session B also runs the tabs suite when touching anything tabs-adjacent.
- Every fix ships with a test that **fails on the old code**. Write the failing test first where practical.
- Keep an implementation-notes log; conservative option + "Deviations" entry when an edge case forces a change; surface it in the final summary.
- TRS refusals only (no `stop()`); all new errors console-visible — but note H5: in the GUI, `message()` is invisible until A2 fixes the capture, so prefer `cat` for anything the GUI user must see.
- When done: state plainly what was verified by execution and what was not. A Fable pre-merge review follows Session A — leave it a clean trail.

---

## 2. Session A — Phase 1: make the numbers honest

Work in this order (each item's file:line evidence is in the review doc):

**A1. Fix the test harness first (§5) — it gates everything else.** Fix the project-root finder in `test_hb_estimation.R`/`test_guard_fixes.R` (add a walk-up-four-levels candidate or set `TURAS_ROOT` in `helper-setup.R`); make the HB tests actually run (bayesm is installed). Retarget the 8 MNL end-to-end tests at a small committed synthetic fixture under `modules/conjoint/tests/fixtures/` (config + data built by the existing generator) — do NOT create a repo-root `examples/` tree without asking. Make the node-path check use `Sys.which("node")` and skip honestly if absent. Acceptance: suite runs with materially fewer skips and any skip that remains is environmental, not structural.

**A2. Fix GUI honesty (H4, H5).** Status-check `run_conjoint_analysis()`'s return in `run_conjoint_gui.R` before the success banner; refusals get an error notification + the refusal text. Capture both streams (`type = c("output","message")`). Also M10's trivia while in the file: remove/wire the phantom `input$client_name`, add `on.exit` restore around the `setwd`.

**A3. Fix C1 (LC all-zero utilities).** In `calculate_utilities` (`04_utilities.R:30`), dispatch `latent_class` through `extract_hb_utilities` (the LC result carries `attribute_map`/`col_names`/`individual_betas`). Add the safety net: refuse (`CALC_ALL_ZERO_UTILITIES`) if every non-baseline utility is exactly zero after extraction, naming the likely cause. Tests: LC pipeline test on synthetic data asserting non-zero utilities + non-zero importance; extraction test on `attr_level`-named coefficients.

**A4. Fix C3 (SE/CI/p from heterogeneity SD) per locked decision 4.** In `extract_hb_results` (`11_hierarchical_bayes.R`), compute the population-mean posterior SE from the retained draws of the mixture means; keep `apply(individual_betas, 2, sd)` as a separate `heterogeneity_sd` field. Update `extract_hb_utilities` (SE/CI/p from the new SE; add a Heterogeneity column), the report table builder (`02_table_builder.R` "Std. Error" + new column), Excel Raw Coefficients (`07_output.R:385-402` — stars now honest for HB), and LC (`13_latent_class.R:587-588`; kill the `std_errors = rep(0,…)` p=0 path at `:698`). Tests: SE ≪ heterogeneity SD on synthetic data with known heterogeneity; no p=0 rows from LC extraction.

**A5. Fix C2 (BW simultaneous) per locked decision 3.** `estimate_best_worst_model(method="simultaneous")` refuses with the actionable message; template/manual mention sequential only. Add the missing `best_worst` to `valid_methods` (H2 — one word, `01_config.R:690`) so the sequential path is reachable from config at all. Tests: refusal on simultaneous; config-load acceptance of `estimation_method = "best_worst"`; BW sequential recovery test (synthetic truth → sign/rank recovery).

**A6. Fix H1 (set-only grouping).** Group by respondent × choice set in `validate_none_choices`, `detect_none_option` method 2, `handle_implicit_none` (`09_none_handling.R`) and BWS validation (`10_best_worst.R:67-94`) — copy the correct pattern from `02_data.R:246-251`. Tests: explicit-None and BWS datasets with per-respondent repeated set IDs must validate/estimate.

**A7. Fix H7 (bayesm row-order assumption).** In `prepare_bayesm_data`, sort each respondent's rows by choice set (and stable alternative order) before building `y`/`X`; refuse if a set's rows are non-contiguous after sort or alternative counts vary (the p-consistency check exists — extend it). Tests: shuffled-row synthetic data recovers the same utilities as ordered data.

**A8. Fix H8 engine side (None in estimation).** Recommended minimal-honest scope: when an explicit None alternative is present, refuse estimation with a clear message that None-alternative estimation is not yet supported (name the data change that removes None rows), OR implement the ASC properly (none dummy column, product attributes = 0 for None rows, propagate the estimated none utility). Implementing is preferred if it stays contained; refusing is acceptable — log the choice. Either way, kill the current path where None rows silently become all-NA factors. (The simulator side — exporting `noneUtility` — is Session B, B1.)

**A9. Fix H6 (interactions).** Surface `interaction_terms` in `load_conjoint_config`'s config object; reconcile `auto_detect_interactions`/`interaction_auto_detect` to one name; fix `analyze_interaction`'s coefficient-name matching to mlogit's `:` convention. Then the honesty gate: if interactions were estimated, `extract_attribute_utilities` must not silently drop them — either represent them in the utilities output or refuse simulator generation for with-interaction models (`CALC_INTERACTIONS_NOT_IN_SIMULATOR`) rather than simulating main-effects shares from a with-interactions model. Refusing the simulator is the conservative default; log it. Tests: config round-trip; with-interactions run either carries interaction utilities or refuses the simulator — no silent main-effects output.

**A10. Fix H9 (WTP).** Anchor both WTP tables to the documented baseline-relative definition (compute aggregate WTP from raw, not zero-centred, coefficients; baseline rows = 0/omitted); check the price-coefficient sign (refuse or prominently warn on positive slope); label the CI honestly (it is an approximation from a K-point OLS — say so in the sheet) or drop it. Fix M8 while there: honour "blank skips WTP" or fix the template/guard text to match auto-detect (recommend the latter — auto-detect is documented in README/manual). Tests: baseline rows zero; aggregate and individual WTP agree in sign and anchor on synthetic data; wrong-signed price refuses.

**A11. Fix H10 (LC round-robin) + H12 (custom-slide leak) + H3 (optimizer surface).** H10: replace the silent round-robin with a refusal; use the class-conditional likelihood (or at least the existing k-means with a PARTIAL notice) for assignment — never assign meaninglessly under PASS. H12: honour `include_custom_slides` via `safe_logical`; ship the template's example slide as a help row the loader skips (or empty sheet). H3 per locked decision 7: delete the OPTIMIZER template section + validator block + orphaned optimizer functions (or leave the functions with a TODO if Duncan vetoes deletion — log it).

**A12. Fix M1-M3 (stats pack + config honesty).** M1: derive `impl_label` from `model_result$method` ("bayesm rhierMnlRwMixture (HB)" / "mlogit (MNL)" / "clogit (MNL fallback)"); WTP flag from the actual `wtp_result`; packages list from the method; attach `diagnostics$fit_statistics` to what the stats pack actually reads and fix the `log_likelihood` field name. M2: read `generate_stats_pack` case-tolerantly, config "N" wins over the GUI checkbox unless the box is actively ticked. M3: make the aggregate path honour `zero_center_utilities`; remove `base_level_method` from template/validator (effects coding doesn't exist) or implement it — removal recommended, log it. M5: warn on unknown setting names, refuse duplicates (mirror tabs `config_utils.R:110-124`).

**A13. Fix M4 (HB importance method).** Wire `calculate_attribute_importance_hb` into the main pipeline for HB and LC runs (`00_main.R:463` branches on method); keep the aggregate function for MNL. Expose the per-respondent importance matrix in the return value (Session B's exporter needs it — build the plumbing now). Tests: HB importance ≠ aggregate importance on heterogeneous synthetic data; per-respondent rows sum to 100.

**A14. Remaining M-tier, judgment allowed on scope:** M6 (report which Alchemer score branch fired + the level-cleaning old→new mapping; refuse on −1/0/1 coding rather than silently treating −1 as unchosen), M7 (delete dead config keys from template+docs, or wire `default_customers` — wiring that one is cheap and real), M9-M11 (fix if trivial while in the file, else log). H11 (guard layer): wire `validate_conjoint_config`/`validate_wtp_config`/`guard_check_data_exists` into `run_conjoint_analysis_impl` at their natural steps and delete what stays uncalled — do not leave the limbo. Log every choice.

Definition of done for Session A: suite green with the new tests in and the §5 structural skips gone; every review-doc ID above either fixed (with test) or logged as deliberately deferred; summary states what was executed. Then Duncan regens + a **Fable independent pre-merge review** runs (brief it as independent — no shared working notes, per the standing review-independence rule).

---

## 3. Session B — Phases 2+3: report quick fixes + tabs exporter

**B1. Report/simulator fixes (P1-P8 from the review doc).** P1: move insight persistence to a JSON script-tag island written via `textContent` (mirror the slides pattern at `conjoint_navigation.js:415-437`); hydrate must prefer user content over the seed. P2: JS-escape before HTML-escaping in inline handlers, or switch the touched sites to `data-*` + addEventListener. P3: compute the WTP chart height in a first pass, then draw. P4: NA-guard the Geweke/ESS/WTP/convergence conditionals and wrap `.build_all_tables` in a TRS-refusal-producing tryCatch. P5: `</`-escape all islands (mirror `build_report_v2.R:87`) + save-side hardening. P6: delete the dead JS + dead `lib/html_simulator` files per locked decision 7; fix the help-overlay text; update CODE_INVENTORY.md (counts + the missing directory). P7: importance chart descending; guard the class-size normalisation; escape the two raw SVG label sites. P8: fix if trivial, else log. Also H8 simulator side: export `noneUtility` (and scale it consistently with product utilities) in `.build_simulator_data`. Tests: extend `test_html_report.R`/`test_html_simulator.R` — an apostrophe-bearing attribute name, a `</script>` payload, and an NA Geweke z must all round-trip/refuse cleanly.

**B2. Tabs exporter (new `R/16_tabs_export.R`).** Opt-in via `generate_tabs_export` (Settings, default N). Input: post-A13 per-respondent importance matrix + `respondent_id_column`. Output workbook `{project_name}_tabs_importance.xlsx`:
- Sheet DATA: respondent ID column named exactly as the configured `respondent_id_column`, plus per-respondent importance shares in columns `{QCode}_1..{QCode}_k` (`QCode` from new setting `tabs_question_code`, default `CJIMP`), k = number of attributes. Matches tabs' Allocation contract (`allocation_processor.R:79`). Rows with `total_range == 0` (all-zero importance) are excluded and counted on the METHOD sheet.
- Sheet QUESTIONMAP_SNIPPET: the QuestionMap row (`QuestionCode`, `QuestionText = "Conjoint attribute importance (model-derived, {method})"`, `Variable_Type = "Allocation"`, `Columns = k`) + Options rows (attribute names, in column order).
- Sheet METHOD: estimator (bayesm HB: iterations/burn-in/thin, convergence verdict; or LC: k, entropy), n exported / n excluded (zero-range), RLH quality-flag counts, disclosure that estimation is unweighted and tabs will weight at reporting.
- Honest-sig gate per locked decision 5: refuse (`CALC_NO_RESPONDENT_UTILITIES`) unless method is HB or LC.
- Deferred per locked decision 6: no per-level Numeric columns in v1 — leave a clearly-marked extension point.
Tests: column naming contract; shares sum to 100 per exported respondent; refusal under `auto`/`mlogit`; snippet correctness; integration proof — feed the exported DATA sheet shape to tabs' Allocation processor in a unit test and assert one mean row per attribute. Do not run real projects.
Docs: USER_MANUAL section + README feature bullet.

---

## 4. Session C — Phase 4: v2 report (GATED)

Do not start until master-doc work-item **OPUS-0** (socket consolidation) is done and Duncan green-lights. Then execute per `V2_MIGRATION_PLAN.md` §8 with these conjoint specifics:
- Serialize via `build_dl_question()` row kinds `cj_utility` (zero-centred level utilities + honest post-A4 CIs), `cj_importance`, `cj_fit`, optionally `cj_wtp` — each needs `classify_row_labels()` (R) **and** `forQuestion()` + `d2.validate()` (JS) arms; a kind missing either side silently doesn't render.
- One new view `27x_conjoint.js` (model on `27d_diffs.js`, ~400-700 LOC): importance ranking, per-attribute utility bars with CI whiskers, model-fit panel, optional WTP panel. Chart designs carry over from `05_chart_builder.R` as *specs only* — do not port R-generated SVG.
- Start from `transform_conjoint_for_html()` — it already produces the sectioned aggregate list; emit it as a data island instead of rendering it.
- Curated bar: HB diagnostics (Geweke/ESS/RLH), individual utilities, LC deep-dive stay in Excel — log against the §7 drop-list.
- Freeze not live: pre-aggregated rows only; **no per-respondent betas in any v2 island** (locked decision 2; the classic sim island already carries them — that stays in the classic deliverable). Any `nEff` comes from `modules/tabs/lib/weighting.R::calculate_effective_n`.
- v2 report links to the classic combined report/simulator as the simulator deliverable. Retire System A's report path only after Duncan confirms v2 supersedes it; the combined report+simulator build path stays.
- Open item to chase first: whether the live simulator JS consumes the embedded individual betas (methods page claims aggregate-only, `03_page_builder.R:1177`) — resolves whether the classic island can be slimmed.

---

## 5. What NOT to do (any session)

- Do not port the old HTML report to v2 (wrong layer — migration plan §2).
- Do not modify anything in OneDrive or client deliverables; never headless-run real projects.
- Do not implement Stan/cmdstanr anything here — conjoint HB is bayesm and stays bayesm (PROG-1 is a maxdiff concern).
- Do not build the per-level Numeric export or a joint BW estimator — both are explicitly deferred decisions.
- Do not "improve" beyond the work orders; log ideas in the deviations notes instead.
- Do not merge to main; do not push. Duncan merges after regen + eyeball.
