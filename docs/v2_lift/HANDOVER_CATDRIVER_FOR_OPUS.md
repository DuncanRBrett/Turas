# CatDriver Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-11. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/CATDRIVER_PRODUCTION_REVIEW_2026-07-11.md` (the findings — every fix below references its IDs C1-C3, H1-H11, M1-M12, P1-P8, §5); (3) for Session C only, `modules/tabs/docs/V2_MIGRATION_PLAN.md` **plus** `docs/v2_lift/HANDOVER_KEYDRIVER_FOR_OPUS.md` §4 (TR.KD island — TR.CD rides its scaffolding). Load the `fable-method` skill. Project CLAUDE.md rules apply throughout (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the catdriver row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by the Fable review (Duncan may veto; if he does, the vetoing message wins). Review §8 lists the items awaiting his ruling — check the tracker row for veto notes before starting.

1. **No tabs exporter for catdriver — ruled out, not deferred.** Outputs are aggregate; per-respondent fitted probabilities are D5-inadmissible (model-smoothed copies of a tabs-native outcome column with artificially reduced variance) and redundant. Do not build one.
2. **V2 route: tracking-style frozen `TR.CD` island + own workspace view, zero new row kinds**, sequenced **after** keydriver's TR.KD and reusing its serializer conventions and shared JS components. Separate view, not a merged driver view — catdriver's level-resolution content (OR forest, lifts, patterns) is the centrepiece.
3. **`multinomial_mode` is amputated, not implemented:** engine + guard accept `baseline_category` only; other values refuse with an honest "not implemented" message; template dropdowns/docs stripped to match.
4. **Weights: normalise to mean 1 at ingestion** (console note + degraded-reason when raw scale ≠ 1), report Kish n_eff/deff, stamp inference "frequency-weight approximation; design effect not applied". No `survey`-package rebuild.
5. **Honest provenance everywhere (D5):** every importance row carries its computing method (LR-share / Wald-share / z²-fallback); the equal-importance fallback **refuses** instead of fabricating 100/k; stats pack stamps come from what actually ran, never from config or hardcoded strings.
6. **Template fixed loader-side** (header-row discovery). `modules/shared/lib/template_styles.R` serves 9 other modules — do not touch it. Follow keydriver's loader-side pattern.
7. **Dead code deleted:** `00_guard.R` dead gates + stale `catdriver_refuse` (the C3 fix), `lib/validation/preflight_validators.R`, `cd_pinned_views.js`, `cd_slide_export.js`, `generate_catdriver_comparison_report`, deprecated `extract_odds_ratios`, `verify_or_direction`, `calc_mcfadden_r2`, dead `prepare_analysis_data` + colliding `format_missing_report` twins. CODE_INVENTORY.md corrected in the same commit.
8. **Session split:** Session A = correctness (engine + refusal system), Session B = config/GUI/template/docs + report fixes, Session C = v2 (gated on OPUS-0 **and** TR.KD landing). One branch per session: `feature/catdriver-correctness`, `feature/catdriver-config-and-report-fixes`, `feature/catdriver-v2-report`. Do not merge — Duncan merges after his eyeball.

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run pipelines against real project folders, never write into OneDrive.
- Suite command: `Rscript -e 'testthat::test_dir("modules/catdriver/tests/testthat", reporter = "summary")'`. Baseline 2026-07-11: **0 fail / 4 warn / 1 skip / 659 pass**. Run before your first change and after every fix. Two baseline warnings ("non-integer #successes") disappear when A2 lands — that is expected and good.
- Every fix ships with a test that **fails on the old code**. The suite currently passes *around* all three CRITICALs (review §5) — your new tests must close those structural holes, including sourcing in **GUI order** for the refusal-shape test (the helper's sorted order masks C3).
- TRS refusals only (no `stop()`); all new errors console-visible. The GUI's console capture is the good shared `capture_console_all` — no sink workarounds needed here.
- Keep an implementation-notes log; conservative option + "Deviations" entry when an edge case forces a change; surface it in the final summary.
- When done: state plainly what was verified by execution and what was not. A Fable pre-merge review follows Session A — leave it a clean trail.

---

## 2. Session A — correctness (`feature/catdriver-correctness`)

Work in this order (file:line evidence for each is in the review doc):

**A1. Fix C3 (refusal system) first — everything else's error paths depend on it.** Delete `00_guard.R`'s `catdriver_refuse` and its dead gate/duplicate-helper functions (locked decision 7); make `08_guard.R`'s definition the single live one; remove the 00_guard sourcing block from `00_main.R:49-59` if nothing live remains (check `catdriver_guard_init` callers first — review says zero). Regression test: source files in **GUI order** (`run_catdriver_gui.R:579-600`), feed a deliberately broken config, assert a clean `turas_refusal_result` with `run_status == "REFUSE"` and non-empty fix text — not BUG_INTERNAL_ERROR.

**A2. Fix C1 + H1 + H2 (weights through the likelihood machinery).** Normalise weights to mean 1 at extraction (`00_main.R:670-674`; console note + degraded-reason if rescaled; count NA→1 and negative→0 imputations, report them — M6). Carry the weight vector into `calculate_multinomial_importance` and pass it to every reduced-model refit (`05_importance.R:213-214`) and to all three null-model refits (`04a_ordinal.R:221-223,331-333`, `04b_multinomial.R:195-197`). Weighted binary glm: expect the "non-integer #successes" warning to vanish under `quasibinomial` or suppress-with-stamp — pick the conservative option that keeps coefficients identical (quasibinomial does) and log it. Add the D5 inference stamp (locked decision 4) to Model Summary + stats pack. Tests: weighted-multinomial importance recovery (synthetic truth → rank correlation; assert all chi-squares ≥ 0); weighted McFadden R² ∈ [0,1]; SE invariance to weight rescaling.

**A3. Fix C2 (subgroup comparison).** Align `build_or_comparison` (`11_subgroup_comparison.R:265-292`) to the mapper schema (`factor/comparison/odds_ratio/or_lower/or_upper/factor_label`) — rename at the consumer, don't touch the mapper. Make comparison failure degrade to PARTIAL with a degraded-reason instead of silent NULL (`00_main.R:522-528`). Tests: real-mapper-schema fixtures through `build_subgroup_comparison` end-to-end (importance matrix, classification, OR table, model fit all non-NULL); a failure-injection test asserting PARTIAL + reason.

**A4. Fix H3 + H4 (ordinal safety).** H3: `guard <- guard_warn(...)` and fix the `guard_flag_stability` arity at `08b_guards_soft.R:222-230`; test that the direction-sanity path fires without crashing and registers its warning. H4: hard-refuse when `outcome_type = "ordinal"` and `outcome_order` is empty (mirror `guard_ordinal_levels_order`, `08a:552-579`); update template/docs to mark Order required for ordinal outcomes. Test: text-labelled ordinal outcome without Order → refusal naming the setting.

**A5. Fix H5 + M1 (bootstrap honesty).** Replace `tryCatch(..., warning = NULL)` at `07_utilities.R:943` with `withCallingHandlers` + `muffleWarning` so weighted fits survive; count and report discarded resamples with their reasons; when `bootstrap_ci` was requested but `bootstrap_results` ends NULL, record a degraded-reason → PARTIAL. Tests: weighted-binary bootstrap produces CIs; enabled-but-failed bootstrap yields PARTIAL.

**A6. Fix H6 (multinomial_mode amputation, locked decision 3).** Guard accepts `baseline_category` only; `04b` whitelist matches; other values refuse with "only baseline_category is implemented"; strip modes from `generate_config_templates.R` dropdowns, guard fix-texts, TECHNIQUE_GUIDE/USER_MANUAL/06_TEMPLATE_REFERENCE. Test: `one_vs_all` config → refusal, message names the setting.

**A7. Fix H11 + M5 (provenance).** Stats pack: importance method from the actual path (store the method string where importance is computed — "LR chi-square share (car::Anova II)" / "LR-test share (multinomial refits)" / "z² fallback"); `weighted` from whether weights were actually applied; real `n_excluded`/`questions_skipped` from the missing-report; Declaration reads the loader's actual keys (`config$settings$Project_Name` etc. — or map them in the loader, `B` fixes the doc side). Importance output gains a `method` column (D5 — the island needs it). Equal-importance fallback (`05:174-188`) becomes a refusal (locked decision 5). z²-fallback path (`05:43-46`): keep as fallback but stamp it in the output and add a degraded-reason.

**A8. Remaining engine M-tier, judgment on scope:** M2 (EPP gate → minority-class events per parameter, all outcome types), M3 (at minimum: stop claiming clm "has built-in tests" — run `ordinal::nominal_test`/`scale_test` if cheap, else disclose "PO assumption not tested" in diagnostics), M4 (relabel probability lift honestly — "difference in mean fitted probability", name the multinomial outcome level in the table; full AME is out of scope), M6 (already in A2). Log what you chose.

**A9. §5 test additions** not covered above: guard-arity test; template-load round-trip (belongs to B if you prefer — coordinate); dead-code deletion (locked decision 7) with CODE_INVENTORY correction — deleting `prepare_analysis_data` removes its tests too (they test the dead twin).

Definition of done for Session A: suite green with new tests in; every ID above fixed-with-test or logged as deliberately deferred; summary states what was executed. Then Duncan regens + a **Fable independent pre-merge review** (briefed as independent — no shared working notes).

---

## 3. Session B — config/GUI/template/docs + report fixes (`feature/catdriver-config-and-report-fixes`)

**B1. Template + loader (H7, locked decision 6).** Loader-side header discovery in `01_config.R` (scan for the row whose cells are `Setting`/`Value`; ditto Variables/Driver_Settings/Slides), tolerant of the banner/legend rows the shared template writer emits. Test: shipped template loads; example config still loads; a garbage workbook still refuses cleanly.

**B2. GUI honesty (H8).** Use the existing `is_refusal()` helper + treat any `run_status` other than PASS/PARTIAL as failure in `run_catdriver_gui.R:706-726`; failed runs get an error notification and are **not** appended to `analyses` for the unified report. Single-config summary reflects real status. Test at the function level (extract the status-classification into a testable helper).

**B3. Config-surface honesty (H9, H10, M7, M9, M10, M12).** H9: give `00_main.R` a real source-all block (mirror the GUI list) or ship a `source_catdriver.R` loader and fix README/USER_MANUAL/WORKFLOWS to use it. H10: fix template dropdowns (add `binary`, drop `nominal`) and the doc examples (`nominal` → `multinomial`); `per_outcome` dies in A6. M7: `Generate_Stats_Pack` honest three-state (setting > GUI option > default) so the checkbox works. M9: warn on unrecognised Settings rows (mirror tabs `config_utils.R`); `as_logical_setting` returns the supplied default on unparseable input, with a console warning naming the setting; same for `as_numeric_setting`. M10: only send GUI branding overrides the user actually edited (compare against the prefill). M12 + minors: doc corrections (missing_strategy default, reference_category wording, Instructions-sheet claim, stale 01_README copy, version identity — pick `CATDRIVER_VERSION` as the single truth and generate the rest).

**B4. Report quick fixes (P1-P6 + selected P7).** P1: give Overview sections `cd-page-active` (or exempt `.cd-comp-section` from the hide rule) — the unified flagship must not open blank. P2: move slide md/image stores to script-tag `textContent` (TurasPins pattern) and fix `hydrateCard`. P4: emit nav links only for sections the panel actually contains. P5: include `cdToggleHelp` + overlay in unified (or drop the button there). P6: `htmlEscape` the subgroup SVG labels. P7 judgment set — do at minimum: **OR narration fix** ("more likely" → honest odds phrasing in transformer, table builder, forest zones — client-facing honesty), startup JS guard checks the files actually embedded, dead-JS deletion + CODE_INVENTORY (locked decision 7), triplicate badge id, dose-response narrative gated on ordinal drivers. Log the rest as deferred with reasons. Tests: extend `test_html_report.R` — unified Overview renders visible sections; a `</script>` payload and a `<24h` label round-trip; slide-store persistence pattern.

**B5. Shared-library fix (P3) — SUPERSEDED 2026-07-12: pulled into OPUS-0** (`docs/v2_lift/HANDOVER_OPUS0_FOR_OPUS.md` §0.1 + W3). Skip this item unless Duncan vetoes that pull-in, in which case the original order below stands. — `</script>` hardening in `modules/shared/js/turas_pins.js`. Escape `</` in `_save`'s JSON island write and unescape in `_load` (mirror `build_report_v2.R:88-89` semantics). This touches **every TurasPins module**: run the tabs suite plus at least one other TurasPins module's suite (brand or keydriver), and grep for any other consumer of the island format before changing it. If the blast radius looks larger than a session can verify, split this into its own micro-branch `fix/turas-pins-script-hardening` and say so — do not skip it silently.

**B6. Platform docs (M11, pending Duncan's §8-7 confirmation):** remove SHAP from `launch_turas.R:153`, top-level `CLAUDE.md:57`, top-level `README.md:30`.

---

## 4. Session C — v2 TR.CD island + view (GATED)

Do not start until **OPUS-0** (socket consolidation) is done, **TR.KD has landed** (keydriver Session C), and Duncan green-lights. Then:
- Frozen island `TR.CD` (`data-catdriver`), zero new row kinds, serialized per TR.KD's conventions with a `module` discriminator. Content per review §6 Phase 4: importance (with `method` column from A7), ORs per level (Wald + bootstrap CIs, sign stability), probability lifts, factor patterns, model fit/diagnostics (incl. n_excluded, weighting stamp, nEff), subgroup matrix (post-A3 only). "Report filters do not apply here" notice, tracking-style.
- Own workspace view reusing TR.KD's shared components (importance bars + method stamp, subgroup heatmap, diagnostics drawer) + catdriver-specific OR-forest / lifts / patterns panel. No sig letters on model estimates — CIs only (D5).
- `nEff` exclusively from `modules/tabs/lib/weighting.R::calculate_effective_n`.
- Curated bar (D1): exhaustive per-level diagnostics stay in Excel; log anything left behind against V2_MIGRATION_PLAN §7's drop-list.
- Retire System A's report path only after Duncan confirms the v2 view supersedes it.

---

## 5. What NOT to do (any session)

- Do not build a tabs exporter or export per-respondent fitted probabilities anywhere (locked decision 1).
- Do not implement one_vs_all / all_pairwise / per_outcome — amputate (locked decision 3).
- Do not touch `modules/shared/lib/template_styles.R` (9 other modules).
- Do not change `09_mapper.R` semantics — it is the strongest part of the engine; A3 renames at the *consumer*.
- Do not swap in `survey`-package design-based inference — normalise + stamp only (locked decision 4).
- Do not modify anything in OneDrive or client deliverables; do not regenerate real projects.
- Do not "improve" beyond the work orders; log ideas in deviations notes.
- Do not merge to main; do not push. Duncan merges after regen + eyeball.
