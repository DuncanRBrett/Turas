# MaxDiff Module — Production Review & V2 Lift Plan

**Status:** Review complete, no code changed. This document is the freeze artifact for the fix/build sessions.
**Date:** 2026-07-10
**How it was built:** four parallel independent code readers (statistical engine; config/UX layer; report gap-vs-tabs-v2; tabs-integration feasibility) + test-suite run + spot verification of the critical claims by the coordinating session. Every finding below was verified by reading the named lines or running the named command this session, except where explicitly labelled otherwise.
**Baseline facts:** module last touched 2026-04-21 (`git log -- modules/maxdiff`) — it predates the entire tabs-v2 era. Test suite (`testthat::test_dir("modules/maxdiff/tests/testthat")`) passes with 0 failures, 4 skips — but see §5: the suite is structured to pass *around* the critical defects, not through them.

---

## 0. Executive verdict

The statistical specifications are sound on paper (clogit best/worst with sign negation is the standard formulation; the Stan model is correctly written; the shared TURF engine is clean). But the module is **not solid**: three CRITICAL plumbing defects mean HB-derived deliverables are silently wrong or silently downgraded, the shipped config template cannot complete an ANALYSIS run, and the GUI reports success on refusal. Counts and aggregate-logit point estimates are trustworthy **only** for ID-coded, unweighted, complete data with the respondent ID in column 1.

The current HTML report is previous-generation architecture (server-side pre-rendered HTML with hidden per-segment divs) and is a dead end per `modules/tabs/docs/V2_MIGRATION_PLAN.md` (2026-07-05), which already plans this module's migration. The simulator is architecturally v2-like (JSON island + JS compute engine) and should stay standalone per that plan.

**Order of work: fix correctness first (Phase 1), then quick report fixes (Phase 2), then tabs integration (Phase 3), then the v2 lift (Phase 4).** There is no point giving wrong numbers a better report.

---

## 1. CRITICAL — silently wrong client-facing numbers

### C1. The Stan HB path errors out and silently falls back to empirical Bayes
`R/07_hb.R:283-295` — `prepare_stan_data()` returns the full data list including `item_ids = included_items` (always **character**: `01_config.R:566` + `clean_item_id()` at `utils.R:490-502`) and `resp_ids`. `stan_model$sample(data = stan_data)` (`07_hb.R:141`) passes the whole list; cmdstanr writes the entire list to JSON and its `write_stan_json` stops on character vectors *(verified against cmdstanr master source fetched during review — not run locally; cmdstanr is not in this renv)*. The `tryCatch` at `07_hb.R:154-160` converts the error to a single `[TRS PARTIAL] MAXD_MCMC_FAILED` `message()` and `fit_approximate_hb()` runs instead.

**Consequence:** even on a machine with cmdstanr correctly installed, every "HB" deliverable (`HB_Utility_Mean/SD/Q5/Q95`) is actually empirical-Bayes-shrunken count scores (bw ∈ [-1,1]), mislabelled as Bayesian utilities. Preference shares exp-normalise these compressed scores, flattening differentiation. On this Mac, cmdstanr isn't installed at all, so the fallback is unconditional.
**Fix:** pass only `N,R,J,K,resp,choice,shown,is_best` (+ declare/pass `anchor_item` properly, see M1) to `$sample()`. Add a sampling-path test (can be a mock/write_stan_json-level test if cmdstanr absent).

### C2. Numeric respondent IDs become a phantom "item" in preference shares, TURF, discrimination
`utils.R:697-699` keeps all *numeric* columns of `individual_utilities`; the first column is `resp_id` (`07_hb.R:445-450`, EB path `:486-492`). Survey exports very commonly have numeric IDs (openxlsx reads them numeric). A resp_id like 10001 dominates every per-respondent softmax → "resp_id" gets ~100% share, all real items ~0%. Same defect in `classify_item_discrimination` (`utils.R:807-809`) and the shared TURF engine (`modules/shared/lib/turf_engine.R:255-257` — TURF step 1 picks "item" resp_id at 100% reach and stops). Verified: `00_main.R:1050` and `lib/html_report/01_data_transformer.R:202,275` pass the whole data frame in.
**Fix:** drop the `resp_id` column by name at every consumer (or better: have producers return the matrix + separate id vector). Add tests with a numeric-ID column present.

### C3. Position-coded best/worst data validates cleanly and scores as all zeros
`02_validation.R:399-413` explicitly accepts position values `1..items_per_task`. But `build_maxdiff_long()` only matches choices against Item_ID strings (`03_data.R:518-519`); no position→Item_ID translation exists anywhere (`grep -rn ITEM_POSITION R lib tests` → nothing). The USER_MANUAL (§4.6, §5.4) and the shipped template *recommend* `ITEM_POSITION` — which is also how Sawtooth/Alchemer typically export.
**Consequence:** counts table ships with Best%=Worst%=Net=0 for every item; logit refuses with misleading `DATA_NO_VALID_CHOICES`; HB EB-fallback gets all-zero scores. The test fixture itself is position-coded and the logit tests hand-convert instead of calling `build_maxdiff_long` — which has **zero direct tests**.
**Fix:** implement position decoding in `build_maxdiff_long()` (explicit `Value_Type` setting to resolve ambiguity), or remove positions from `valid_positions` and refuse with an actionable message. Implementing is strongly preferred — it is the most common real-world export format.

---

## 2. HIGH

- **H1. Segments merge on the data's first column, not the configured ID.** `08_segments.R:218` `resp_id_var <- names(raw_data)[1]`. Wrong/NA segment assignment whenever the ID isn't column 1 (standard in Alchemer exports). Fix: use `config$project_settings$Respondent_ID_Variable`.
- **H2. Typo'd `Weight_Variable` silently becomes weight=1 while everything reports "weighted".** `03_data.R:472-476`; `weighted=TRUE` flags at `00_main.R:844,952,969`. `validate_maxdiff_weights()` (`02_validation.R:555`) exists, is tested, and is **never called** in production. Fix: refuse when `Weight_Variable`/`Respondent_ID_Variable` set but absent from data; wire the weight validation in.
- **H3. Silent task-row fallback can misattribute choices to items never shown.** `03_data.R:497-504` falls back to `version_design[t, ]` by row position when Task_Number lookup fails — no warning. Fix: refuse or count+warn on any fallback; cross-check mapping task count vs design.
- **H4. GUI reports "completed successfully" on a refusal.** `run_maxdiff_gui.R:392-423` never status-checks the result; green toast + "✓ MAXDIFF ANALYSIS COMPLETE" regardless. Fix: branch on refusal.
- **H5. `message()` output (all TRS PARTIAL notices, incl. the C1 fallback notice) is invisible in the GUI.** `run_maxdiff_gui.R:389` sinks stdout only. Fix: sink `type="message"` too (matching un-sink in `finally`), and stream the capture file during long runs.
- **H6. The shipped config template cannot complete an ANALYSIS run.** SURVEY_MAPPING sheet uses a `Mapping_Type`/pattern schema (`create_maxdiff_template.R:459-506`) the loader doesn't support (`01_config.R:802-815` requires `Field_Type`/`Field_Name`); SEGMENT_SETTINGS schema likewise mismatched (template/manual: `Segment_Name/Variable_Value/Include/Display_Order`; code: `Segment_Label/Segment_Def/Include_in_Output`, `01_config.R:914`, `08_segments.R:235-240`). Template default `Data_File_Sheet="1"` breaks `read.xlsx` (verified empirically: `sheet="1"` errors, `sheet=1` works). Fix: regenerate template against the real loader schema (one file: `create_maxdiff_template.R`).

---

## 3. MEDIUM (engine + honesty)

- **M1.** HB ignores the designated anchor: Stan hard-codes the *last* item (`maxdiff_hb.stan:40,52`); `anchor_item` passed but not declared in the data block. Logit honours `Anchor_Item` (`06_logit.R:70-78`) → the two utility columns in one workbook are anchored to different items.
- **M2.** Tasks lacking exactly one best + one worst are dropped silently (`06_logit.R:218`, `07_hb.R:241`) while counts *include* those tasks in `Times_Shown` → denominators inflated by non-response; counts and logit run on different effective data, undisclosed.
- **M3.** Logit SEs/p-values treat sampling weights as frequency weights and ignore within-respondent clustering (`06_logit.R:124-138,314-315`) → overstated precision.
- **M4.** An `Include=0` item still present in the fielded design gets an all-zero indicator (statistically a second anchor), biasing all coefficients (`06_logit.R:112-118,208`); in the Stan path it produces NA → data-write failure → silent EB fallback.
- **M5.** EB fallback's `HB_Utility_SD` is between-respondent heterogeneity, not a posterior SE, yet the HTML report renders it as "SE" (`lib/html_report/01_data_transformer.R:267`); Q5/Q95 likewise population spread, not credible interval.
- **M6.** Stats pack **fabricates provenance**: claims "HB (ChoiceModelR package)" (`00_main.R:773-775,865`) — ChoiceModelR is not used anywhere in this module. `tasks_per_resp` reads a nonexistent `Task` column → always "—" (`00_main.R:766`).
- **M7.** Weighting inconsistent across engines: counts/logit weighted; Stan model has no weight term; EB fallback unweighted; TURF supports weights but the caller never passes them (`00_main.R:1050-1052`). One weighted study mixes weighted and unweighted numbers, undisclosed.
- **M8.** Count-CI machinery is anti-conservative (uses Times_Shown as binomial n, `05_counts.R:297-301`) — but it and the segment-significance functions are dead code (never called in production). Net effect today: **segment tables ship with no significance testing at all**.
- **M9.** Respondents with NA design version vanish silently (`03_data.R:479`).
- **M10.** Config parsing silently drops unknown/typo'd/duplicate setting names (`01_config.R:436-437,1004-1031`); `parse_yes_no` returns default on garbage. Tabs refuses duplicates (`config_utils.R:110-124`) — adopt that.
- **M11.** Stats pack default contradiction: code defaults `Generate_Stats_Pack` **on** (`00_main.R:415-417` reads it from project_settings) while the template puts it in OUTPUT_SETTINGS where it is silently dropped, and the GUI checkbox can only turn it on, never off.
- **M12.** Manual documents `Generate_HTML_Report/Simulator/TURF` defaults as YES; code defaults all three FALSE (`01_config.R:1077-1079`). Recommend defaulting the report ON.
- **M13.** Best/worst mapping rows pair positionally when Task_Number extraction fails — and extraction only matches *trailing* digits, so the template's own `MaxDiff_T1_Best` naming yields NA (`01_config.R:875-886`, `03_data.R:441-442,497-504`).
- **M14.** Four template sheets are decorative: STUDY_IDENTIFICATION (stats pack reads PROJECT_SETTINGS instead, `00_main.R:854-855`), REPORT_SETTINGS (branding read from project_settings; logo paths settable *only* in the dead sheet), IMAGES (never loaded; `build_panel_images` always empty), plus OUTPUT_SETTINGS rows that the parser drops (incl. `Utility_Scale` — the real setting is `Score_Rescale_Method`, absent from the template).
- **M15.** Docs reference things that don't exist: `examples/maxdiff/demo_showcase/` (nowhere in repo — verified by find), `{Project}_log.txt` (no code writes a log), `tests/test_maxdiff.R`, `examples/basic/`, template "in docs/". No generated example report exists anywhere in the repo to eyeball.

## 4. Report/simulator bugs (current System A — fix even though it will be replaced)

- **P1a.** Every simulator pin click throws `TypeError: SimPins.getCount is not a function` — the loaded pins module (`sim_pins.js:214`) exports only `captureView`; `getCount` exists only in `simulator_pins.js`, which is **never loaded** (`99_simulator_main.R:131,218` reads `sim_pins.js`). Badge permanently dead. (`simulator_ui.js:441,452,502`)
- **P1b.** `simulator_pins.js` (461 lines) is dead code; `docs/CODE_INVENTORY.md:75,134,174` documents it as the live module. Delete + fix inventory.
- **P1c.** Save Report loses typed insights: `md_report.js:199-202` writes `store.value` on a hidden textarea; `.value` doesn't serialise via `outerHTML` (`:312-333`). Pins persist correctly because TurasPins uses `textContent` on a script tag — do the same.
- **P2a.** Inconsistent HTML escaping in SVG charts: labels unescaped in 5 of 7 charts (`04_chart_builder.R:87,244,410,439,587`; escaped at `:171,692`). `"Speed & reliability <24h"` breaks the markup.
- **P2b.** Simulator JSON island not `</script>`-hardened (`02_simulator_page_builder.R:216`); same for insight config JSON (`03_page_builder.R:138`). Tabs v2 guards this (`build_report_v2.R:88`).
- **P2c.** Segment-chart legend overflows the 720px viewBox from 5 levels up (`04_chart_builder.R:403-405,370`).
- **P3.** Minor: em-dash sorts as 0 (`md_report.js:158-159`); pin postMessage bridge has no origin check (`md_pins.js:522-527`, `sim_pins.js:173-176`); labels hard-truncated at ~22-25 chars in every chart; 8-colour palette recycles at 9+ levels; `sys.frame(1)$ofile` path resolution in `02_simulator_page_builder.R:57` silently yields unstyled standalone simulators; report written without `useBytes=TRUE` (`99_html_report_main.R:698`); dead `build_h2h_with_segments`; "v11.2" hardcoded ×3.

## 5. Test-suite honesty

Green (0 fail) but: `build_maxdiff_long` — zero direct tests; cmdstanr sampling path never exercised; `compute_maxdiff_counts` math untested; shares/TURF tested only with bare matrices lacking a resp_id column; two logit anchor tests are empty stubs; one design test *skips itself when the call fails*; logit tests swallow errors via `tryCatch(...NULL)` + `if (!is.null(...))`; pervasive `skip_if(!exists(...))` turns sourcing failures into silent skips. Required additions: direct `build_maxdiff_long` tests (both codings), recovery tests (synthetic truth → estimate correlation) for logit and HB-fallback, counts-math tests incl. weighted + partial data, numeric-resp_id tests for shares/TURF/discrimination.

---

## 6. The lift: way forward in four phases

**Phase 1 — Make it honest (blocks everything).** C1-C3, H1-H6, M1-M2, M5-M7, M11-M12 + the §5 test additions + template regeneration (H6) + doc-drift fixes (M15 quick pass). Everything is specified above with file:line.

**Phase 2 — Current-report quick fixes.** P1a-c, P2a-c (small, keeps live deliverables honest while the v2 lift lands; the migration plan sequences maxdiff last, so System A lives for a while).

**Phase 3 — Tabs integration (S effort, high value).** Zero-tabs-change route verified: maxdiff already exports INDIVIDUAL_UTILS (resp_id + item columns, `09_output.R:147-151,706-731`, on by default `01_config.R:1076`), keyed on the same `Respondent_ID_Variable` as the survey data. Build a small maxdiff-side "tabs export": per-respondent softmax **preference shares** (loop already exists, `utils.R:706-712`; shares sum to 100 → a genuine Allocation payload), written as `{code}_1..{code}_k` columns (Allocation naming contract, `allocation_processor.R:79`) + an emitted QuestionMap/Options snippet. Tabs then gives utilities-by-banner with t-test sig letters using the existing Allocation type. Design cares: (a) stamp the estimation method — Stan vs EB fallback produce different scales (C1/M5); (b) honest-sig policy: t-tests on model estimates ignore posterior uncertainty and EB shrinkage attenuates segment differences — consider footnote or no-test default under EB; (c) base drift when maxdiff `Filter_Expression` excluded respondents; (d) weighting double-dip policy (estimate weighted + report weighted?). Aggregate-only outputs (TURF, anchor, discrimination) cannot enter tabs as questions — they stay in the maxdiff report; report_hub already bundles maxdiff reports (`report_hub/01_html_parser.R:83,95`).

**Phase 4 — V2-level reporting.** Execute per `modules/tabs/docs/V2_MIGRATION_PLAN.md`: do **not** port the old HTML (wrong layer); emit v2 data islands (`build_dl_question` row kinds for utility / pref-share / BW / anchor-rate / TURF-step), add one `27x_maxdiff.js` view (~400-700 LOC by analogy with `27d_diffs.js`/`27t_tracking.js`) + `forQuestion()`/`d2.validate()` arms. Keep the simulator standalone (plan §1.2 recommendation; its engine JS is already the v2 pattern). Prerequisite: the plan's Phase-0 socket hardening (single Kish n_eff, single disclosure gate, TurasPins retirement) and verifying the 2026-07-02 audit stats bugs are closed in `21_stats.js`. Retires ~6,800 LOC of System A eventually. Chart designs (diverging bars, strategy quadrant, TURF curve) carry over as specs for v2 chart kinds. The plan's three open decisions (parity-vs-curated, simulators, module order) are Duncan's; its §7 capability drop-list applies (HB utilities, Rhat/ESS, TURF must not fall out silently).

## 7. Model recommendation (Fable vs Opus)

Per the handy-guide principle — expensive model on decisions and verification, cheap on execution:

- **Phase 1 + 2: Opus 4.8, high effort,** with this document as the spec. The hard diagnostic work is done; every fix is localised and named. Escalate to **Fable only for the final pre-merge review** of the engine fixes (silent-wrong-number territory earns the independent Fable pass).
- **Phase 3: Opus 4.8.** Small, well-specified; the design decisions (honest-sig, method stamping) are framed above for Duncan to rule on first.
- **Phase 4: split.** The migration plan's Phase-0 socket hardening is cross-cutting architecture touching every future migration — **Fable, once**. The maxdiff migration itself was explicitly designed to be executable by "an Opus session reading the plan and nothing else" — **Opus 4.8**, with the plan + this doc.
- Sonnet 5 is suitable for the doc-drift/template-regeneration mechanical parts of Phase 1 if run against this spec.

## 8. Decisions Duncan owns before build starts

1. The migration plan's three open decisions (§1 there): parity vs curated (rec: curated); simulators standalone (rec: yes); module order — does maxdiff pull rank over segment/keydriver?
2. ITEM_POSITION: implement decoding (recommended — it's how platforms export) or refuse explicitly?
3. Honest-sig policy for model-estimate columns in tabs (footnote vs no-test under EB fallback).
4. Phase 1 scope check: fix-everything-first (recommended) vs fast-track Phase 3/4 in parallel.
