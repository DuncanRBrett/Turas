# MaxDiff Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-10. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/MAXDIFF_PRODUCTION_REVIEW_2026-07-10.md` (the findings — every fix below references its IDs C1-C3, H1-H6, M1-M15, P1-P3, §5); (3) for Session C only, `modules/tabs/docs/V2_MIGRATION_PLAN.md`. Load the `fable-method` skill. Project CLAUDE.md rules apply throughout (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the maxdiff row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by Duncan: **maxdiff jumps the migration queue** (goes first, before segment/keydriver).
Locked by the Fable review (Duncan may veto; if he does, the vetoing message wins):

1. **Curated content bar** for the v2 report, not parity. Decision-grade content migrates; exhaustive diagnostics stay in the Excel deliverable. Log every capability deliberately left behind against the drop-list in V2_MIGRATION_PLAN §7.
2. **Simulator stays standalone**, linked from the report. Do not embed it in v2.
3. **ITEM_POSITION gets implemented**, not refused (spec in §3, fix C3). It is the dominant real-world export format.
4. **Honest-sig for exported utilities:** tabs export is allowed only from genuine Stan HB estimates. Under the EB fallback the exporter refuses by default (override: `Allow_Approx_Utilities_Export = YES`, which stamps the method prominently). Never let EB-shrunken scores masquerade as HB in a sig-tested crosstab.
5. **Session split:** Session A = Phase 1 (correctness), Session B = Phases 2+3 (report fixes + tabs exporter), Session C = Phase 4 (v2 migration, **gated** on programme work-item OPUS-0 in the master doc). One feature branch per session: `feature/maxdiff-correctness`, `feature/maxdiff-report-fixes-and-tabs-export`, `feature/maxdiff-v2-report`. Do not merge — Duncan merges after his eyeball.

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run the full pipeline against real project folders, never write into OneDrive.
- Suite command: `Rscript -e 'testthat::test_dir("modules/maxdiff/tests/testthat", reporter = "summary")'`. Run before your first change (baseline: 0 fail / 4 skip as of 2026-07-10) and after every fix. Session B also runs the tabs suite when touching anything tabs-adjacent: `testthat::test_dir("modules/tabs/tests/testthat")`.
- Every fix ships with a test that **fails on the old code**. Write the failing test first where practical.
- Keep an implementation-notes log; conservative option + "Deviations" entry when an edge case forces a change; surface it in the final summary.
- TRS refusals only (no `stop()`); all new errors console-visible (`cat`/`message` — but note H5: in the GUI, `message()` is invisible until you fix the sink, so prefer `cat` for anything the GUI user must see).
- When done: state plainly what was verified by execution and what was not. A Fable pre-merge review follows Session A — leave it a clean trail.

---

## 2. Session A — Phase 1: make the numbers honest

Work in this order (each item's file:line evidence is in the review doc):

**A1. Fix C2 (numeric resp_id poisons shares/TURF/discrimination).** Drop the `resp_id` column **by name** in `compute_preference_shares` (utils.R), `classify_item_discrimination` (utils.R), and at the maxdiff call-site into the shared TURF engine (00_main.R:1050) — do not change `modules/shared/lib/turf_engine.R` semantics without checking its other caller (brand module) first; if the engine itself must change, add an explicit `id_col` argument defaulting to current behaviour. Tests: shares/TURF/discrimination with a numeric `resp_id` column present; assert no phantom item.

**A2. Fix C1 (Stan HB dead on arrival).** In `fit_hb_model` (07_hb.R), pass to `$sample()` only the variables the Stan model declares: `N,R,J,K,resp,choice,shown,is_best`. Keep `item_ids`/`resp_ids`/`anchor_item` in a separate metadata list for `extract_hb_results`. Fix M1 in the same change: reorder items so the designated anchor is **last** before building Stan data (the model hard-codes `beta[r,J]=0`), and map back to original order on extraction — do not edit the Stan model's parameterisation. Tests: `prepare_stan_data` output contains only numeric/integer members; anchor-reorder round-trip preserves item labels. cmdstanr is not installed locally — you cannot run sampling; say so in your summary rather than claiming the Stan path verified end-to-end. Flag to Duncan: adding cmdstanr+CmdStan to renv is his environment decision.

**A3. Fix C3 (position coding).** Add config setting `Choice_Value_Type` (PROJECT_SETTINGS): `ITEM_ID` (default, current behaviour) | `ITEM_POSITION`. In `build_maxdiff_long` (03_data.R), when `ITEM_POSITION`, decode `best_choice`/`worst_choice` as `items_shown[as.integer(choice)]` from that task's design row; refuse on out-of-range positions. In `validate_survey_data` (02_validation.R:399-413): only accept position values when the setting says ITEM_POSITION; when set to ITEM_ID and values look positional, refuse with a message naming the setting. Update USER_MANUAL §4.6/§5.4 and the template accordingly (see A6). Tests: direct `build_maxdiff_long` tests for **both** codings (this closes the §5 zero-coverage gap) + a counts test asserting non-zero scores from position-coded fixture data.

**A4. Fix H1-H3 (segments/weights/task alignment).** H1: `08_segments.R:218` uses `config$project_settings$Respondent_ID_Variable`, refusing if absent from data. H2: in `validate_survey_data`, refuse when `Weight_Variable` or `Respondent_ID_Variable` is configured but absent from data; wire the existing (currently dead) `validate_maxdiff_weights()` into the production path. H3: remove the silent positional design-row fallback (03_data.R:497-504) — refuse with counts of unmatched tasks; also fix Task_Number extraction to match `T(\d+)` anywhere in the field name, not just trailing digits (M13). Tests for each failure mode.

**A5. Fix GUI honesty (H4, H5) + M-tier labeling.** H4: status-check `run_maxdiff()`'s return in `run_maxdiff_gui.R` before the success toast; refusals get an error notification. H5: sink `type="message"` alongside stdout (matching un-sink in `finally`). M5: label EB-fallback SD/Q5/Q95 columns honestly (they are population spread, not posterior SE — rename in output + report transformer). M6: stats pack method string reflects the actual estimator (Stan vs EB fallback; remove the false ChoiceModelR claims); fix the `Task`→`Task_Number` column read. M2: report dropped-task counts (tasks lacking exactly one best + one worst) in the summary and stats pack; keep behaviour otherwise. M11/M12: `Generate_Stats_Pack` read from where the template puts it, GUI checkbox becomes the honest toggle; default `Generate_HTML_Report=TRUE`.

**A6. Fix H6 + M14 + M15 (template + docs).** Regenerate `create_maxdiff_template.R` against the real loader schema: SURVEY_MAPPING → `Field_Type`/`Field_Name` rows; SEGMENT_SETTINGS → `Segment_Label`/`Segment_Def`/`Include_in_Output`; `Data_File_Sheet` default → integer 1 handling (coerce all-digit strings to integer in `parse_project_settings`); wire or drop the four dead sheets (recommend: wire REPORT_SETTINGS branding keys into what the report actually reads, drop STUDY_IDENTIFICATION/IMAGES rows into PROJECT_SETTINGS equivalents or delete — pick one, log it); OUTPUT_SETTINGS rows match `get_default_output_settings()` (add `Score_Rescale_Method`). Add M10 protections while in `01_config.R`: warn on unknown setting names, refuse on duplicates (mirror tabs `config_utils.R:110-124`). Then fix doc drift: USER_MANUAL/README claims that don't match code (M15 list; delete references to nonexistent examples/log files, or create a minimal working example — smaller is fine, invented is not).

**A7. Remaining M-tier, judgment allowed on scope:** M3 (at minimum: document the SE caveat in output + manual; full robust/clustered SEs only if cheap), M4 (validate excluded-but-present design items → refuse), M7 (disclose per-engine weighting status in the summary sheet; passing weights to TURF is allowed if the shared engine supports it cleanly), M8 (delete or fix the dead CI/sig machinery — deleting dead code + leaving a TODO note is acceptable; do not ship the anti-conservative formula), M9 (count + warn on NA-version respondents). Log what you chose.

**A8. §5 test additions** not already covered above: recovery tests (synthetic truth → estimate rank-correlation) for aggregate logit and EB fallback; counts-math test (Best%/Worst%/Net against hand-computed values, weighted and unweighted); empty-stub logit anchor tests get real bodies; the self-skipping design test asserts instead of skipping.

Definition of done for Session A: suite green with the new tests in, every review-doc ID above either fixed (with test) or logged as deliberately deferred, summary states what was executed. Then Duncan regens + a **Fable independent pre-merge review** runs (brief it as independent of your session — do not share your working notes with it, per the standing review-independence rule).

---

## 3. Session B — Phases 2+3: report quick fixes + tabs exporter

**B1. Report/simulator fixes (P1a-c, P2a-c from the review doc).** P1a: fix the `SimPins.getCount` TypeError (either export `getCount` from `sim_pins.js` or remove the badge calls). P1b: delete `simulator_pins.js`, update `docs/CODE_INVENTORY.md`. P1c: persist insights via `textContent` on a script-tag store (mirror TurasPins' pattern). P2a: `htmlEscape()` labels at the five unescaped chart sites. P2b: `</`-escape the sim-data and insight-config JSON islands (mirror `build_report_v2.R:88`). P2c: wrap or scale the segment legend past 4 levels. P3 items: fix if trivial while in the file, else log. Tests: extend `test_html_report.R`/`test_html_simulator.R` — a label like `Speed & reliability <24h` and a `</script>` payload must round-trip.

**B2. Tabs exporter (new `R/12_tabs_export.R`).** Opt-in via `Generate_Tabs_Export` (OUTPUT_SETTINGS, default NO). Input: `hb_results$individual_utilities` (post-A2, genuinely Stan) + `Respondent_ID_Variable`. Output workbook `{Project_Name}_tabs_utilities.xlsx`:
- Sheet DATA: respondent ID column named exactly as `Respondent_ID_Variable`, plus per-respondent **preference shares** (softmax per respondent, summing to 100 — reuse the loop in `utils.R:706-712` post-A1) in columns `{QCode}_1..{QCode}_k`, `QCode` from new setting `Tabs_Question_Code` (default `MDSHARE`). This matches tabs' Allocation column contract (`allocation_processor.R:79`).
- Sheet QUESTIONMAP_SNIPPET: the row to paste into a tabs QuestionMap (`QuestionCode`, `QuestionText` = "MaxDiff preference shares (model-derived)", `Variable_Type = "Allocation"`, `Columns = k`) and the Options rows (item labels, in column order).
- Sheet METHOD: estimator (Stan HB, chains/iters, Rhat range), n respondents exported, filter expression applied (base-drift disclosure per review §6 Phase-3 care (c)), weighting status (care (d): shares are computed from utilities estimated with weights if configured; tabs will weight again at reporting — state both facts, make no silent choice).
- Honest-sig gate (locked decision 4): if the utilities came from the EB fallback, refuse (`CALC_APPROX_UTILITIES`, actionable message) unless `Allow_Approx_Utilities_Export = YES`; when overridden, METHOD sheet + QuestionText both carry "(approximate — count-based)".
Tests: column naming contract, shares sum to 100 per respondent, refusal under EB, snippet correctness. Integration proof: build a small synthetic end-to-end fixture — maxdiff export → hand it to tabs' Allocation processor in a unit test — and assert tabs produces one mean row per item. Do not run real projects.
Docs: USER_MANUAL section + README feature bullet.

---

## 4. Session C — Phase 4: v2 report (GATED)

Do not start until master-doc work-item **OPUS-0** (socket consolidation) is done and Duncan green-lights. Then execute per `V2_MIGRATION_PLAN.md` §8 checklist with these maxdiff specifics:
- Serialize into the aggregate island via `build_dl_question()` (`modules/tabs/lib/data_layer_writer.R:538`); new row kinds needed: `md_utility`, `md_share`, `md_bw` (best/worst/net counts), `md_anchor`, `md_turf_step`. Each needs an arm in `classify_row_labels()` (R) **and** `forQuestion()` (`22_model.js`) plus `d2.validate()` extensions — a kind missing either side silently doesn't render.
- One new view `27x_maxdiff.js` (model on `27d_diffs.js`/`27t_tracking.js`, ~400-700 LOC): item ranking with utilities + shares, best-worst diverging bars, TURF incremental curve, anchor must-have panel. Chart designs carry over from `04_chart_builder.R` as *specs only* — do not port R-generated SVG.
- Curated bar (locked decision 1): HB diagnostics (Rhat/ESS) and individual utilities stay in the Excel deliverable; log against the §7 drop-list.
- Freeze vs live: pre-aggregate (freeze) — no maxdiff microdata island in v1 of this view; segment cuts ship as pre-computed rows (the §6 file-size ceiling; the simulator covers live what-if).
- Weighted bases: any `nEff` the serializer emits comes from `modules/tabs/lib/weighting.R::calculate_effective_n` — never a local formula.
- Retire System A's report path only after Duncan confirms the v2 output supersedes it; the simulator and its build path stay.

---

## 5. What NOT to do (any session)

- Do not port the old HTML report to v2 (wrong layer — migration plan §2).
- Do not modify `generate_ipk_9cat_wave1.R`, anything in OneDrive, or client deliverables.
- Do not touch the shared TURF engine's behaviour for its brand-module caller without running brand tests.
- Do not "improve" beyond the work orders; log ideas in the deviations notes instead.
- Do not claim the Stan sampling path works end-to-end unless you actually sampled (cmdstanr may be absent).
- Do not merge to main; do not push. Duncan merges after regen + eyeball.
