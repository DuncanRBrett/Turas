# Segment Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-11. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/SEGMENT_PRODUCTION_REVIEW_2026-07-11.md` (the findings — every fix below references its IDs C1-C2, H1-H3, M1-M8, L1-L5); (3) for Session C only, `modules/tabs/docs/V2_MIGRATION_PLAN.md` §7 and the review's §8. Load the `fable-method` skill. Project CLAUDE.md rules apply (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the segment row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by Duncan (standing): classic v1 HTML report **stays the deliverable** — he parked `feature/segment-report-v2` because he prefers v1. Locked by the Fable review (Duncan may veto; a vetoing message wins):

1. **No dedicated v2 view for segment; no new row kinds.** Segment enters tabs-v2 **as a banner** — its per-respondent assignment is tabs-native microdata and profiles recompute live. This supersedes V2_MIGRATION_PLAN :41 ("mirror the tracking island") and :55 ("segment breakdown rows") for segment — both are false-to-code. Segment-specific diagnostics (silhouette, dendrograms, golden questions, validation) stay in the classic Excel/HTML deliverable under D1; log each to the §7 drop-list. An optional frozen `TR.SG` island is NOT commissioned.
2. **Tabs exporter gets built** (Session C) — the assignment→banner bridge the module's own docstring promises but nothing implements. D5 stamping mandatory: "model-derived grouping (unweighted clustering)" on the banner; in-sample caveat for sig on clustering variables; GMM membership probabilities refuse-as-weights by default.
3. **LCA is amputated, not wired** (C2): remove `use_lca` + `lca_*` from config parsing, template generator, and all doc claims; delete `R/11_lca.R` and `test_lca.R` (recoverable from git). If Duncan wants LCA as a real feature, that is a new commissioned work item with poLCA validation — not this bug fix.
4. **Ensemble is amputated too** (M1): delete `R/14_ensemble.R` + `test_ensemble.R`, drop `"ensemble"` from the hard guard's allowed-list (`00a_guards_hard.R:200`). The math was verified sound — resurrect from git if ever commissioned.
5. **Mini-batch k-means is fixed, not dropped** (C1): correct the dispatcher call, pass `config$seed` through.
6. **Non-k-means scoring refuses honestly** (H2): `score_new_data`/`type_respondent`/batch refuse for gmm/hclust models with a message naming the method and why nearest-centroid would misclassify. GMM-posterior scoring is a future feature, not this fix.
7. **Parked `feature/segment-report-v2` stays parked.** Never merge it (its ~9k-line vendored engine is a stale June-2026 copy of tabs-v2). If a TR.SG island is ever commissioned, harvest only: `data_layer_writer.R`, `40_segment_app.js`, its two R test gates, `PLAN.md` decisions — and re-vendor the engine fresh.
8. **Shared TurasPins `</script>` hardening (M6) is catdriver handover item B5 — do NOT fix it in a segment session.** One shared fix, cross-module suite runs, owned there.

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run pipelines against real project folders, never write into OneDrive.
- Suite: `Rscript -e 'testthat::test_dir("modules/segment/tests/testthat", reporter="summary")'`. Baseline this session (2026-07-11): **0 fail / 1 warn / 1 skip / 1026 pass**. Run before first change and after every fix. Session C also runs the tabs suite.
- Every fix ships with a test that **fails on the old code**; write it first where practical.
- TRS refusals only (no `stop()`), console-visible errors (`cat` for anything a GUI user must see).
- Keep an implementation-notes log; deviations logged and surfaced. A Fable pre-merge review follows Session A — leave a clean trail; do not share working notes with it.

## 2. Session A — correctness (`feature/segment-correctness`)

**A1. Fix C1 (mini-batch dead >10k).** In `R/03_clustering.R:155-161`: remove `nstart=` from the `run_minibatch_kmeans` call (the function has no such arg — repro in review §1) and pass `seed = config$seed`. Decide-and-note whether to add multi-start to `run_minibatch_kmeans` itself (acceptable: not adding it; mini-batch is already approximate). Tests: a `>10000×p` fixture through `run_kmeans_dispatch` in final AND exploration mode (this is the test whose absence let C1 ship); determinism test (same seed → same assignments).

**A2. Apply locked decisions 3+4 (amputate LCA + ensemble).** Remove `use_lca`/`lca_n_classes`/`lca_max_iter`/`lca_n_rep` from `01_config.R:439,471` and the template generator (`10_utilities.R:1700,1797`); delete `11_lca.R`, `14_ensemble.R`, `test_lca.R`, `test_ensemble.R`; drop `"ensemble"` at `00a_guards_hard.R:200`; remove sourcing lines in `00_main.R` (:78, :81 region); scrub doc claims (`docs/01_README.md:16,171,177-179`, `docs/02_SEGMENT_OVERVIEW.md:124,317`, `CODE_INVENTORY.md` if listed). Add a refusal: if a config still sets `use_lca=TRUE` or `method=ensemble`, refuse with `CFG_*` naming the removal (do not silently ignore — that's the bug we're fixing). Regenerate the template via the generator and verify it still loads (the row-1 loader path is sound — review §6).

**A3. Fix H2 (scoring honesty).** In `08_scoring.R`: `score_new_data` and `type_respondent`/`type_respondents_batch` refuse for `method %in% c("gmm","hclust")` (keep the existing lca guard until A2 removes the possibility). While in the file, fix M7: pick ONE confidence formula (recommend softmax — it's the batch/typing one) and use it in both entry points; document it. Tests: refusal per method; confidence consistency across entry points.

**A4. Fix H3 (config silent-drop).** Carry `generate_stats_pack` and `research_house` through `validate_segment_config` (`01_config.R:491-501`) so the template Y/N and GUI checkbox actually control the stats pack (`00_main.R:584-586`) and the Declaration sheet gets `research_house`. Then close the systemic hole: after assembling the validated config, warn (console, named list) about any recognised-template setting present in the input but not carried through — mirror tabs' unknown-setting warning. Tests: `generate_stats_pack=N` produces no stats pack; `research_house` reaches the declaration data structure.

**A5. Fix M2 + M3 + M4 (small correctness items).** M2: rename `clustering_data` → `data` at `04_validation.R:601-608`; leave `calculate_gap=FALSE` defaults as-is; either wire `calculate_gap_statistic_range` behind the existing flag or delete it (decide-and-note). M3: in `05a_profiling_stats.R:58-80` route genuinely-nominal variables (character/factor/unordered) to chi-square on the contingency table; keep KW for numeric few-unique; keep the descriptive-p header. M4: make `validate_input_data` handle non-numeric columns with a refusal instead of erroring (`10_utilities.R` — find the variance check), then convert `test_utilities.R:157-173` from skip-on-error to a hard assertion (the suite's only skip disappears — that is the acceptance signal). M8: have `run_minibatch_kmeans` receive its seed explicitly (done in A1); note ensemble seed item dies with A2.

Definition of done: suite green **with zero skips**, every ID above fixed-with-test or logged deferred, summary states what was executed. Then Duncan regens + independent Fable pre-merge review.

## 3. Session B — GUI + report hygiene (`feature/segment-gui-and-report-fixes`)

**B1. Fix H1 (GUI success-on-refusal).** In `run_segment_gui.R:361-364,395-408,443`: after `with_refusal_handler` returns, check `is_refusal()`/`run_status=="REFUSE"` (see `modules/shared/lib/trs_refusal.R:264-289` for the result shape). Refusals get: boxed console output (code/message/how_to_fix — CLAUDE.md pattern), an error-type `showNotification`, and a results panel that renders the refusal fields instead of reading nonexistent `$mode`/`$k`. Test: a refusing config through the GUI handler path asserts no success status (GUI reactive itself can be exercised at the function level — mirror how other modules' H4-class fixes were tested, e.g. maxdiff Session A5).

**B2. Trace the M5 suspects (exploration + combined modes).** The 2026-06 audit's SUSPECTED list was never traced. For each: `06_exploration_report.R:187,197,289,650,653` `return(NULL)` guards — add a console `cat` naming the dropped section + why; `07_combined_report.R:134` — report skipped methods in the combined report header instead of silent `next`; `07a_combined_builders.R:1302` — verify which diagnostics key combined mode actually produces and fix the read or the write (don't leave the `%||% NA` papering). Tests: empty-metrics fixture → console note present; missing-method fixture → skip surfaced in output.

**B3. Small stuff while in the files.** L4: delete the dead `seg-insight-store` textarea (`03_page_builder.R:208-214`). L2: unify the duplicate refusal codes (pick the `00a` names; keep old codes as aliases only if tests depend on them). L3: tile text at `launch_turas.R:139` → "K-means, hierarchical and GMM segmentation with validation, profiling and typing tools" (or similar; decide-and-note). L5: one-line footnote under the importance table naming the F-normalisation. L1: either parse+document `golden_questions_trees` in config/template or hard-code it; decide-and-note.

## 4. Session C — tabs exporter (`feature/segment-tabs-export`)

NOT gated on OPUS-0 (no v2 island, no shared-socket dependency). Build the bridge the docstring promises (`09_output.R:59-60`):

- **C-1.** New export function (segment side): given the run's assignments + the survey data file path from config, write a survey-file-ready join: assert `config$id_variable` exists in BOTH files, assert uniqueness, LEFT-join `segment_name` onto the survey rows, report join coverage (n matched / unmatched with counts — refuse if coverage < 100% without an explicit `Allow_Partial_Join = YES`). Unassigned/outlier rows get `"Unassigned"` (consistent with `09_output.R:78-79`).
- **C-2.** Emit a QuestionMap/Selection stub sheet (or clearly-named csv) declaring the column as a categorical banner variable, with the D5 stamps from locked decision 2 baked into the label/notes: "Segments (model-derived, unweighted clustering — sig on clustering variables is in-sample)". Check tabs' Selection-sheet expectations in `modules/tabs/lib/banner.R` before finalising the stub shape.
- **C-3.** GMM probability columns are NOT exported to the survey file (D5: estimates; refuse-as-weights). They stay in `segment_assignments.xlsx`.
- **C-4.** Docs: a short "Segment → Tabs banner" section in `docs/01_README.md` replacing the manual-merge folklore. Log to V2_MIGRATION_PLAN §7 drop-list: GMM membership probabilities; silhouette/dendrogram/validation diagnostics; golden-questions screener (stays classic); typing tool (standalone, like the simulators per D2's spirit).
- Tests: join correctness (exact match, partial refusal, duplicate-ID refusal, Unassigned mapping); stub shape; run tabs suite too (`testthat::test_dir("modules/tabs/tests/testthat")`) even though tabs code is untouched — the deliverable claims tabs-compatibility.

## 5. What NOT to do (any session)

- Do not merge — Duncan merges after eyeball. One branch per session, named above.
- Do not touch `modules/shared/js/turas_pins.js` (catdriver B5 owns it) or `modules/shared/lib/config_utils.R`/`template_styles.R` (serve many modules).
- Do not merge or cherry-pick from `feature/segment-report-v2` (locked decision 7).
- Do not add weighting to clustering, per-cell sig letters, or a min-base gate to the classic report — real gaps, but out of scope until Duncan commissions them (they are logged in review §5).
- Do not "improve" the live kmeans/hclust/GMM/validation math — it was verified sound (review §6).
