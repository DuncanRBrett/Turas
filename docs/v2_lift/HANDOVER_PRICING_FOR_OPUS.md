# Pricing Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-11. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/PRICING_PRODUCTION_REVIEW_2026-07-11.md` (the findings — every fix below references its IDs C1-C3, H1-H8, M1-M14, P1-P3, §5); (3) for Session B's exporter, the tabs contracts named in review §6 Phase 3. Load the `fable-method` skill. Project CLAUDE.md rules apply throughout (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the pricing row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by the Fable review (Duncan may veto; if he does, the vetoing message wins):

1. **VW goes weighted** via `pricesensitivitymeter::psm_analysis_weighted()` when a weight variable is configured (C1). If the weighted path fails at runtime, refuse — never silently fall back to unweighted (the maxdiff C1 lesson).
2. **Sequential GG refuses by default** (C2): when per-rung non-NA bases differ by more than a token amount, refuse with per-rung counts; explicit `GG_Stop_Early_Imputation = NO_AFTER_STOP` opt-in converts post-stop NAs to No for descending-acceptance ladders, stamped in output.
3. **Monotonicity semantics get honest** (H3): `flag_only` → `validate=FALSE` (truly retained, disclosed), `drop` → `validate=TRUE`, **default becomes `drop`** (the honest version of today's actual behaviour); analysed n comes from psm's own output; the bootstrap always uses the same `validate` flag and the same weighting treatment as the headline (C3).
4. **No v2 report view for pricing** (curated D1 decision, review §6 Phase 4). The consolidated report is kept and patched; the simulator **stays embedded** and the standalone fork is deleted (P3c). Do not build a `27p_pricing.js` view or pricing row kinds.
5. **Tabs integration is documentation-first + one small exporter** (review §6 Phase 3): VW/monadic questions are declared tabs-side (no pricing code); pricing ships a GG 0/1 acceptance-grid export + optional WTP export, both D5-stamped. WTP export requires wiring the currently dead extractor and a mandatory id_var.
6. **Session split:** Session A = Phase 1 (correctness), Session B = Phases 2+3 (report fixes + tabs exporter). One feature branch per session: `feature/pricing-correctness`, `feature/pricing-report-fixes-and-tabs-export`. No Session C. Do not merge — Duncan merges after his eyeball.

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run the full pipeline against real project folders, never write into OneDrive.
- Suite command: `Rscript -e 'testthat::test_dir("modules/pricing/tests/testthat", reporter = "summary")'`. Baseline as of 2026-07-11: **0 fail / 0 skip / 63 warnings**. Run before your first change and after every fix. Session B also runs the tabs suite when touching anything tabs-adjacent.
- Beware the suite's structural green (review §5): `setup.R` tryCatch-sources and every test `skip_if(!exists(...))` — if your change breaks sourcing, the suite can still pass. After any change to a sourced file, confirm the test count did not drop.
- Every fix ships with a test that **fails on the old code**. Write the failing test first where practical.
- Keep an implementation-notes log; conservative option + "Deviations" entry when an edge case forces a change; surface it in the final summary.
- TRS refusals only (no `stop()`); all new errors console-visible. Note M12: the GUI discards captured output on plain crashes — prefer TRS refusals (whose box IS the condition message) for every new failure mode.
- When done: state plainly what was verified by execution and what was not. A Fable pre-merge review follows Session A — leave it a clean trail.

---

## 2. Session A — Phase 1: make the numbers honest (`feature/pricing-correctness`)

Work in this order (each item's file:line evidence is in the review doc):

**A1. Fix H1 + H2 (template → loader path — unblocks everything else's testing).** Add the Monadic-style name map (`01_config.R:591-607` is the pattern) to `load_van_westendorp_config` and `load_gabor_granger_config`; build one shared separator-tolerant list parser (accept `,` and `;`) and use it for GG `price_sequence`/`response_columns`, the Settings-sheet fallback path, and ladder `tier_names`; align template text (`generate_config_templates.R`) and regenerate the shipped template xlsx. Tests: generate→load round-trip asserting the lowercase keys are populated from a template-shaped config (this is the test whose absence shipped H1); separator variants both parse.

**A2. Fix C1 (weighted VW).** Route weighted runs through `psm_analysis_weighted()` — verified this session (2026-07-11): the function is exported by the installed `pricesensitivitymeter` (1.3.3) and `survey` is in renv.lock and installed. It takes a `survey::svydesign`. Unweighted runs keep `psm_analysis()`. On weighted-path error: TRS refusal (`CALC_VW_WEIGHTED_FAILED`), never a fallback. Stats pack states which path ran. Tests: weighted fixture where weighted OPP ≠ unweighted OPP (assert they differ and match a hand-checked direction); refusal test with a broken design.

**A3. Fix C3 + H3 (CI/estimator coherence + monotonicity semantics).** Wire `validate` to `VW_Monotonicity_Behavior` per locked decision 3; bootstrap uses the same flag and same weighting as the headline (weighted bootstrap = resample within the weighted-estimator world — keep the weighted resampling only if the headline is weighted); CI table's `estimate` column reports the actual headline point, bootstrap mean moves to its own column; report psm's `invalid_cases`/analysed-n in diagnostics, stats pack, and segment tables; fix the "flagged but retained" wording. Tests: CI-vs-point consistency (point within CI on clean data; estimate column == headline point); flag_only vs drop now produce different numbers on an intransitive fixture.

**A4. Fix C2 (sequential GG).** Per locked decision 2: compute per-rung non-NA bases in `calculate_demand_curve` (or upstream), refuse (`DATA_GG_UNEQUAL_BASES`) when they differ beyond tolerance, honour `GG_Stop_Early_Imputation = NO_AFTER_STOP` (wide format: after a respondent's first No in ascending price order, impute No for higher rungs; refuse the setting for long-format data unless order is derivable), stamp the imputation in the summary and stats pack. Tests: stop-early fixture refuses by default; with imputation, demand at high rungs is lower than the naive computation; per-rung bases disclosed.

**A5. Fix H4 + H5 + H6 (monadic + coding honesty).** H4: normalise weights to mean 1 before the glm, caveat the p-value in output (design-effect note), refuse grossing-scale weights (mean far from 1 after normalisation attempt = sum(w) >> n on entry). H5: validate declared-binary GG/monadic response columns — refuse on values outside {0,1} with an explicit `{1,2}` mapping option (`Binary_Coding = ONE_TWO`); kill the "auto" response coding for anything that feeds deliverables or exports (M5) — require explicit response_type. H6: weighted cell means in `13_monadic.R:104`. Tests: 1/2-coded fixture refuses; ONE_TWO mapping produces correct intent; weighted cell means ≠ unweighted on a weighted fixture.

**A6. Fix H7 + H8 + M2 (stats pack honesty).** H7: Kish `(Σw)²/Σw²` as "Effective N" (compute locally with a TODO referencing programme item OPUS-0's shared helper; do NOT hand-roll a second copy anywhere else), keep "Valid N" separate. H8: read `config$Generate_Stats_Pack` from the flat list; GUI checkbox becomes authoritative. M2: return `monotonicity_violations` from `validate_pricing_data` so the Excel disclosure block actually renders. Tests for each.

**A7. Fix M1 (smoothing) + M14 (bootstrap weighting policy).** Replace the inline cummax with the existing PAVA implementation (`smooth_isotonic`, `04:400-457`) wired to the `Smoothing_Method` setting; GG bootstrap smooths inside each replicate so the CI band brackets the published curve; align GG bootstrap resampling with the VW policy chosen in A3 (one documented policy). Tests: smoothed curve is monotone non-increasing and never above-only-adjusted (PAVA pools, not raises); CI band brackets the smoothed curve on a synthetic fixture.

**A8. Config + template + doc honesty sweep (M4, M6-M11).** M6: warn on unknown setting names, refuse on duplicates (mirror tabs `config_utils.R:110-124`); fix the section-divider regex so mixed-case headers don't leak in as settings. M7/M8: outlier settings and Min_Sample — implement or remove from template+manual+defaults (recommend: implement Min_Sample as a real refusal — it's cheap; remove outlier settings and the README stats-pack claim, log the removal). M9: remove dead `interpolation_method`/`PI_Scale` or wire them. M4: keep "fix" but document the re-sort semantics in template + manual (it is a strong transformation). M10: correct `sample_config_comprehensive.R` (entry point, option names, delete phantom CSV references) and the USER_MANUAL `price_min`/`price_max` keys. M11: template example AddedSlides row and example Simulator scenarios must not load as real content from an unedited template — mark them as help rows the loader already filters. M12: assign `captured` before the tryCatch error path in `run_pricing_gui.R` so crash context isn't discarded; capture the message stream too.
Judgment allowed on scope for M13 (dead Phase-3 API tier): minimum = README/TECHNIQUE_GUIDE stop implying WTP/competitive/optimisation sheets exist in the pipeline, delete the never-rendering output blocks or gate them honestly; do NOT wire the dead tier into the pipeline in this session (WTP wiring is Session B's exporter, narrowly). Log what you chose.

**A9. §5 test additions** not already covered above: golden-value tests — hand-computed VW price points on a tiny fixture (e.g. 5 respondents whose ECDF intersections are checkable by hand), GG optimum on a hand-computed demand/revenue schedule, monadic optimum sanity; a main-pipeline test that FAILS if any step refuses (the CFG_TIER_NAMES_MISMATCH ladder refusal currently hides inside a passing test); template round-trip (A1).

Definition of done for Session A: suite green with the new tests in, every review-doc ID above either fixed (with a test) or logged as deliberately deferred, summary states what was executed. Then Duncan regens + a **Fable independent pre-merge review** runs (brief it as independent of your session — do not share your working notes with it).

---

## 3. Session B — Phases 2+3: report fixes + tabs exporter (`feature/pricing-report-fixes-and-tabs-export`)

**B1. Report persistence + correctness (P1a-c).** P1a: persist insights via `textContent` on a script-tag store (TurasPins' pattern, `turas_pins.js:257-260`); hydration prefers the freshest source. P1b: same for Added-Slides content; only re-render from the editor when non-empty. P1c: `updateChart` takes both `prices` and `intents` from the selected segment's object — fix in `pricing_simulator.js` (the live copy) and, if the fork survives until this session lands, `simulator_core.js` (it shouldn't — see B3).

**B2. Hardening + labels (P2a-c, P3a-b).** P2a: `</script>`-escape the PRICING_DATA/PRICING_CONFIG islands and the insight-config JSON; replace the hand-rolled `jsonEscape` with real JSON serialisation + island escaping (mirror `build_report_v2.R:88`). P2b: escape `data-tooltip` attribute values. P2c: pass `currency_symbol` into the VW chart builder. P3a: one "Revenue Index" scale — recommend raw `price × intent` everywhere with the scenario table showing "% of optimum" as a separately-labelled column; segment view indexes to the segment's own optimum. P3b: fix or remove the dead `TurasSimulator` save branch. P3e items: fix if trivial while in the file, else log. Tests: extend the html-report/simulator tests — a label like `Spend "R50+" & more` and a `</script>` payload must round-trip; segment-chart data contract test.

**B3. Delete the standalone simulator fork (P3c, locked decision 4).** Remove `lib/simulator/` (builder, `simulator_core.js`, css) + its tests; update any docs/inventory references. The embedded simulator tab is the single engine.

**B4. Tabs exporter (new `R/14_tabs_export.R`).** Opt-in via `Generate_Tabs_Export` (default NO). Output workbook `{project}_tabs_pricing.xlsx`:
- Sheet DATA: respondent ID column named exactly as the configured `id_var` (**mandatory** when export is on — refuse otherwise; never the row-order fallback), plus: GG acceptance grid as already-coded 0/1 columns `{QCode}_1..{QCode}_k` (QCode from `Tabs_Question_Code`, default `GGACC`), one column per rung in ladder order, coded by the explicit response_type from A5 (auto-coding refused for export); optionally WTP column when `Export_WTP = YES` — wire `extract_wtp_vw`/`extract_wtp_gg` narrowly for this (they are currently dead code; id-keyed, weighted extraction already written), refuse if id_var missing.
- Sheet QUESTIONMAP_SNIPPET: rows to paste into a tabs QuestionMap — GG grid as `Multi_Mention`, `Columns = k`, Options rows = price labels with currency, in column order; WTP as `Numeric` with suggested Min/Max bins; plus ready-to-copy rows for the VW four questions and monadic cell/intent **pointing at the original survey columns** (documentation rows — tabs reads those columns from the survey file directly; pricing exports nothing for them).
- Sheet METHOD (D5 stamping): per payload — GG grid: "observed acceptance, coded {rule}"; WTP: "derived: midpoint of VW cheap/expensive" or "highest accepted GG price (right-censored at {top rung})"; the validation-exclusion base (`pricing_valid` definition below); weighting status (estimates weighted per config; tabs will weight again at reporting — state both).
- DATA also carries a `pricing_valid` 0/1 flag column reproducing the module's analysed base (validation exclusions), so tabs filters can reconcile bases (review §6 base-drift care).
Tests: column naming contract; 0/1 domain; refusal without id_var; refusal on auto-coded responses; WTP censoring stamp present; integration proof — feed the export to tabs' `Multi_Mention`/Numeric processors in a unit test and assert sane rows. Do not run real projects.
Docs: USER_MANUAL section + README feature bullet; note in TECHNIQUE_GUIDE that VW/monadic questions go to tabs directly via QuestionMap.

**B5. Doc corrections for the plan-level record.** Add a short "pricing" correction note to `modules/tabs/docs/V2_MIGRATION_PLAN.md` ONLY if Duncan asks; otherwise log in your summary that the plan's pricing rows (standalone simulator, WTP, row kinds) are corrected by review §6 — the master tracker row already records it.

---

## 4. What NOT to do (any session)

- Do not build a v2 view, pricing row kinds, or a `data-pricing` island (locked decision 4).
- Do not wire the dead Phase-3 API tier (07/08/09, `test_segment_differences`) into the pipeline beyond B4's narrow WTP use.
- Do not modify anything in OneDrive or client deliverables; do not touch shared libs (`turas_pins*`, tabs processors) except additively with their suites run.
- Do not "improve" beyond the work orders; log ideas in the deviations notes instead.
- Do not claim the weighted VW path verified unless you executed `psm_analysis_weighted()` in a test this session (both it and `survey` are installed — there is no environment excuse).
- Do not merge to main; do not push. Duncan merges after regen + eyeball.
