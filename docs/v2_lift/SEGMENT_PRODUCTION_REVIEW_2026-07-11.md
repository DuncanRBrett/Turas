# Segment Module — Production Review (V2 Lift Programme)

**Date:** 2026-07-11. Method: V2_LIFT_PROGRAM §2 — four parallel independent readers (A statistical engine, B config/UX/doc-drift, C report layer + parked-v2 reconciliation, D tabs/v2 integration), full test-suite run, coordinator (Fable) spot-verification of every CRITICAL (one by execution). Review only; no code changed.
**Suite:** `testthat::test_dir("modules/segment/tests/testthat")` run this session: **0 fail / 1 warn / 1 skip / 1026 pass**. The single skip is itself a finding (M4): `test_utilities.R:173` skips because "validate_input_data errors on non-numeric variance check — source code issue" — the suite green-skips around a known source bug.
**Verification labels:** [CV-EXEC] coordinator-verified by execution; [CV] coordinator-verified by reading/grep this session; [R] reader-verified with quoted file:line evidence; [UNVERIFIED] labelled inline.

**Headline:** segment is in materially better shape than the other five modules reviewed. The shipped template loads (row-1 headers — the keydriver/catdriver defect is absent), the preflight validators are actually called, save-a-copy preserves insights (contentEditable — dodges the keydriver/catdriver textarea bug), escaping is sound, all six 2026-06 audit fixes are verified present, and the live kmeans/hclust/GMM paths are statistically defensible. Its two CRITICALs are dead-on-arrival features, not wrong-numbers-under-PASS.

---

## 1. CRITICAL

**C1. Mini-batch k-means is dead on arrival for any n > 10,000 — raw crash in final mode.** [CV-EXEC]
`R/03_clustering.R:151` auto-selects mini-batch when `n > 10000`; the dispatcher call at `:155-161` passes `nstart = config$nstart %||% 50`, but `run_minibatch_kmeans` (`R/03a_kmeans.R:64-70`) has no `nstart` parameter and no `...`. Coordinator repro this session: `run_minibatch_kmeans(data=d, k=3, batch_size=100, max_iter=10, nstart=25)` → `ERROR: unused argument (nstart = 25)`; identical call without `nstart` runs fine — only the dispatcher call is broken. Final mode hits it bare (`R/00_main.R:235`, no tryCatch) → raw R error, not a TRS refusal (violates the no-`stop()`-class rule); exploration mode's per-k tryCatch swallows it → every k fails → `MODEL_ALL_K_FAILED` with no hint of the real cause. Secondary defect in the same call: `seed` is not passed, so a fixed dispatcher would silently use the hard-coded default `seed=123` instead of `config$seed` (determinism break). Any large CATI/online survey (n>10k) cannot be segmented today.

**C2. LCA is an advertised, config-exposed silent no-op — the 767-line feature is unreachable.** [CV]
Docs headline it: `docs/01_README.md:16` lists "Latent Class Analysis (LCA)" as a fourth method; `:171` explicitly instructs "use `use_lca = TRUE` separately"; `:177-179` document `lca_n_classes`/`lca_max_iter`/`lca_n_rep`; also `docs/02_SEGMENT_OVERVIEW.md:124,317` [R]. The config parser accepts the flag (`R/01_config.R:439,471`) and the template advertises it (`R/10_utilities.R:1700`). But coordinator grep confirms: no file outside the parser/template ever reads `use_lca`; `run_lca` (`R/11_lca.R:134`) has zero callers except `compare_kmeans_lca` (`11_lca.R:730`), which itself has zero callers; `test_lca.R` exercises only helpers. A user following the README gets ordinary k-means with no warning, no refusal, no note. Found independently by Readers A and B. Mitigation (why this isn't mislabelled-numbers): outputs honestly label the method that did run. Same class as catdriver's phantom-SHAP doc-fiction, but worse-facing: here the knob exists and is silently ignored.

## 2. HIGH

**H1. GUI reports "ANALYSIS COMPLETE" + success toast on engine refusals.** [R — same class as all five prior modules]
`run_segment_gui.R:361-364`: `turas_segment_from_config()` runs under `with_refusal_handler()` (`modules/shared/lib/trs_refusal.R:264-289`), which catches the refusal condition and *returns* a result list — no error thrown — so the GUI's `list(success = TRUE, result = result)` marks every refusal a success; `:395-408` then prints "✓ ANALYSIS COMPLETE" and fires the success notification. The results panel (`:443`) tests `result$error`, a field refusals don't have (they carry `run_status="REFUSE"`/`refused=TRUE`), then reads `result$mode`/`result$k` which don't exist. Deeper refusals (preflight, data prep, guards, clustering) all present as success. Step-2 config-summary validation (`:210-274`) is the only path that surfaces refusals correctly.

**H2. Scoring/typing a non-k-means saved model silently applies the k-means rule.** [R]
`score_new_data` (`R/08_scoring.R:266-276`) and `type_respondent` (`:531-543`) assign by nearest Euclidean centroid unconditionally. Guards exist only for `method=="lca"` (`:454`, `:631`); GMM/hclust/ensemble models pass straight through. A saved GMM classifies by posterior probability under fitted covariances — nearest-centroid can disagree with the model's own training assignments, so typing new respondents against a GMM model produces silently wrong (non-reproducing) assignments under normal-looking output. For k-means the rule is correct (verified sound, §6).

**H3. `validate_segment_config` silently drops any template setting it doesn't enumerate — two documented settings are dead controls.** [R]
The validated config is rebuilt from explicit lists (`R/01_config.R:491-501`); unenumerated keys vanish. Consequences found: (a) `generate_stats_pack` (template + generator `10_utilities.R:1671` advertise Y/N; GUI checkbox `run_segment_gui.R:285-287` defaults off) is never carried through, so `00_main.R:584-586` sees NULL → `%||% "Y"` → stats pack **always** generates regardless of config or checkbox; (b) `research_house` (`00_main.R:1171`, generator `10_utilities.R:1710`) is always NULL — the stats-pack Declaration sheet never gets the value the user typed. The mechanism is systemic: any future template knob not added to the enumeration silently no-ops.

## 3. MEDIUM

- **M1. `method="ensemble"`: three layers disagree; 370-line implementation dead.** Config parser refuses it (`01_config.R:249` `valid_methods <- c("kmeans","hclust","gmm")` [CV]) so it fails safe, but the hard guard allows it (`00a_guards_hard.R:200` `allowed <- c(...,"ensemble")` [CV]) and its refusal text advertises it; the dispatcher switch (`03_clustering.R:53-64` [CV]) has no ensemble arm. `run_ensemble_clustering` (`14_ensemble.R`) has zero production callers [CV — grep]. Ensemble math itself is sound (§6).
- **M2. Gap statistic effectively unavailable + latent undefined-variable bug.** `04_validation.R:601-608` references `clustering_data` where the parameter is `data` → would error, caught to `gap=NA`; all three call sites pass `calculate_gap=FALSE` (`00_main.R:252,796`, `10_utilities.R:1085`) so it never fires; `calculate_gap_statistic_range` (`04_validation.R:956`) has no callers. [R]
- **M3. Nominal categoricals get Kruskal-Wallis in the enhanced-profile sig path.** `05a_profiling_stats.R:58-80`: `<10 unique values` routes to `kruskal.test`; the comment promises "Chi-square or Kruskal-Wallis" but chi-square is never called — nominal codes (e.g. region 1–9) are tested as ordered. Mitigated by the honest descriptive-p header (`:13-21`) and by the live path using ANOVA via `create_full_segment_profile` (`00_main.R:304`). [R]
- **M4. `validate_input_data` errors on non-numeric input; suite green-skips around it.** `test_utilities.R:157-173` wraps the call in tryCatch and *skips* ("known source issue") when it errors [CV — read the test + saw the skip fire in this session's run]. The utility should refuse, not error.
- **M5. Exploration & combined report modes still carry the 2026-06 audit's untraced SUSPECTED silent-drops.** Zero commits to `06_exploration_report.R`/`07_combined_report.R`/`07a_combined_builders.R` since the audit [R — git log]. Live suspects: six `return(NULL)` guards (`06_exploration_report.R:187,197,289,650,653`); `07_combined_report.R:134` `next` silently skips a method from the agreement matrix; `07a_combined_builders.R:1302` wrong-key `%||% NA` degrades the CH column to "-". Final-mode report is hardened; these two modes were never swept.
- **M6. Shared TurasPins JSON island not `</script>`-hardened — segment inherits.** Island at `lib/html_report/03_page_builder.R:217-221`, written by `modules/shared/js/turas_pins.js:260` via `JSON.stringify` (no escaping). Cross-module defect already scoped as catdriver handover B5 — do **not** fix it segment-side. [R]
- **M7. Two different assignment-confidence formulas for the same concept.** `1/(1+d)` in `score_new_data` (`08_scoring.R:282`) vs softmax in `type_respondent`/batch (`:550,:743`) — same respondent, different reported confidence by entry point. [R]
- **M8. Mini-batch and ensemble rely on the upstream global seed** (`00_main.R:169`) rather than taking/setting their own — fragile standalone; the C1 fix must pass `config$seed` through. [R]

## 4. LOW

- L1. `golden_questions_trees` read at `00_main.R:403` but never parsed/documented — invisible knob. [R]
- L2. Duplicate refusal codes for the same condition (`CFG_INSUFFICIENT_VARS` at `01_config.R:234` vs `CFG_INSUFFICIENT_VARIABLES` at `00a_guards_hard.R:66`). [R]
- L3. `launch_turas.R:139` tile says "K-means clustering" only — accurate but omits hclust/GMM/multi-method (notably does NOT falsely claim LCA). [R]
- L4. Dead hidden `<textarea id="seg-insight-store">` (`03_page_builder.R:208-214`); no JS references it. [R]
- L5. "Importance %" is F-statistic-normalised (`01_data_transformer.R:219-225`) — sums honestly to 100 but F-stats aren't additively decomposable; worth a footnote, not a bug. [R]

## 5. Report layer vs the tabs-v2 bar (Reader C)

Classic report HAS: shared TurasPins, editable insights that survive save-a-copy (contentEditable + `outerHTML` — architecturally immune to the keydriver/catdriver `.value` loss), per-table CSV export (`03b_page_components.R:389,417` → `seg_utils.js:522`), ANOVA/eta² importance, hand-built SVG charts. LACKS vs v2: per-cell sig letters on profile deltas (grep = 0), weighting (declared honestly: `00_main.R:1160` "Not supported — unweighted analysis" [CV — grep found zero weight handling module-wide]), min-base/disclosure gate on small-segment profiles, live filtering/recompute, native PPTX/story layer. All 6 fixes from `docs/V1_BUG_AUDIT_2026-06.md` verified present on main (I1-I4 + 2 CRITICALs; e.g. `05_chart_builder.R:268,414,1074`, `07_cards.R:163-168`, `03c_section_builders.R:1915`, `09_output.R:78-79`). XSS: user strings escaped at all sampled sinks.

## 6. Good news — verified sound

- **Shipped template loads** — Config sheet headers on row 1, loader (`modules/shared/lib/config_utils.R:33`) reads row 1; empirically loaded, 58 settings parsed [R — by execution]. The keydriver/catdriver template defect is absent. No `"NA"`-stringify (empties dropped, `config_utils.R:115-119`).
- **Preflight validators actually called** (`00_main.R:85-86,194-195`) — unlike keydriver's dead validator file.
- **Core engine defensible:** data prep refuses non-numeric/zero-variance vars, outliers removed before standardisation, scale params saved (`02_data_prep.R:67-79,346-358,580-593`); GMM (correct centre transpose `03c_gmm.R:110-121`, BIC selection), hclust (cophenetic, SS metrics), bootstrap stability with label alignment (`04_validation.R:39-96`), CH/DB guards, `recommend_k` = max silhouette among size-valid k (`04_validation.R:503-521`); effect sizes correct (epsilon² `05a:69`, eta² `05a:93-95`, pooled-SD d `05a:221-223`); k-means scoring reproduces training via saved scale params (`08_scoring.R:233-252`).
- **TRS strong:** 115 `segment_refuse()` calls, prefix enforced (`00_guard.R:71-73`); only two legitimate bootstrap `stop()`s. Documented CLI entry points match real signatures (`01_README.md:43-44,76-77`).
- **Sample-size gates computed correctly** (`00b_guards_soft.R:270-272` uses k_max for exploration; `00a_guards_hard.R:170-172`) — not the catdriver EPP miscount.
- **Honest framing:** profiling p-values documented as descriptive, no FW correction hidden (`05a_profiling_stats.R:13-21`); weighting honestly declared unsupported.

## 7. Extra foci (from the §4 tracker row)

**(a) Assignment-file bridge to other modules: NO automated bridge exists — it is manual today.** [CV]
`export_segment_assignments()` (`R/09_output.R:70-139`) writes `{prefix}segment_assignments.xlsx`, sheet `Segment_Assignments` (`{id_var}`, `segment_id`, `segment_name`, optional `outlier_flag`, GMM `prob_*`/`max_probability`/`uncertainty`), docstring calling it "the join table that feeds the segment-as-banner workflow in tabs" (`:59-60`). Coordinator grep across the repo: zero consumers outside the module (the tabs/tracker "segment" files are banner-column machinery, unrelated — `banner_trends.R:5`, `tracking_segment_bridge.R:14-17`). Duncan manually merges the column into his survey file and declares a banner. The ID key is `config$id_variable` (`01_config.R:226`) — user-chosen, not guaranteed `ResponseID`.

**(b) Parked `feature/segment-report-v2` reconciliation.** [R — via git show/diff, no checkout]
50 segment-scoped new files, +11,104 lines; 10 wip commits, reached Phase 3 (Overview/Profiles-heatmap/Importance/Distinctiveness/Vulnerability/Golden-Questions screener; node-verified against the real engine). Flag-gated (`html_report_v2 = FALSE`), classic stays — no contradiction. Its own `PLAN.md` **retires v1-parity**: lean segmentation-story HTML + push any-question-by-segment crosstabs to tabs via `segment_name` banner — i.e. the branch's division-of-labour decision independently matches this review's integration route. Salvageable if a v2 island is ever commissioned: `data_layer_writer.R` (248 lines — the proven segments→columns `agg` mapping), `40_segment_app.js` (534), two R test gates, PLAN.md decisions. Superseded: the ~9,000-line vendored `assets/js/*` engine — a frozen June-2026 copy; main's engine has diverged heavily; must be re-vendored, never merged as-is. The branch stays parked.

**(c) The 2026-06 six-fix bug audit:** all fixes verified present on main (§5). The audit's exploration/combined SUSPECTED list is the one open remainder (M5).

## 8. Tabs / v2 integration (Reader D; load-bearing negatives coordinator-verified)

**Segment is unique in the programme: its per-respondent assignment IS tabs-native microdata.** The recommended route (full evidence in Reader D's findings, key claims re-grepped by coordinator):

1. **Tabs exporter: YES — effort S; the cleanest fit of all six modules.** Join `Segment_Assignments[{id_var}, segment_name]` onto the survey file by `id_variable` (assert it matches the tabs respondent key), emit the merged categorical column + QuestionMap/Selection banner stub. Once in the survey file, v2's row-index matching needs no runtime join.
2. **NO dedicated v2 profile view.** As a banner, every profile table recomputes live from microdata under existing row kinds — a frozen per-segment island would freeze data that should stay live. Zero new row kinds.
3. **Diagnostics** (silhouette, dendrograms, golden questions, validation) stay in the classic Excel/HTML deliverable under D1, logged to V2_MIGRATION_PLAN §7's drop-list (GMM membership probabilities already listed at :87). Optional future `TR.SG` frozen island + view (effort M) only if Duncan asks.
4. **D5 stamping:** segment-as-banner is admissible (sig tests run on real survey responses across segments) with: "model-derived grouping" stamp; caveat that sig on the *clustering variables themselves* is in-sample/circular-optimistic; GMM membership probabilities refuse-as-weights by default.
5. **Weighting mismatch documented:** clustering is unweighted (zero weight handling module-wide [CV]); weighted tabs runs will show different segment sizes/profiles than segment's own report — must be stated on the exported banner.

**False V2_MIGRATION_PLAN premises found (5th/6th across the programme):** (i) `:41` "segment … per-segment summary rows mirror the tracking island" — inverted; segment's output is live microdata, the frozen-island route is wrong for its profiles; (ii) `:55` "segment breakdown rows … added to classify_row_labels()/forQuestion()" — banner route needs zero new row kinds; (iii) `:36` internally contradicts itself (lists "assignment rows" as static report content while the same row correctly calls assignment "a bridge feed … not a UI").

## 9. Suite honesty

0 fail / 1026 pass is *more* honest than the other five modules' suites (real fixtures, HTML report actually rendered in-suite), but: the one skip papers over M4; `test_lca.R` tests helpers of a feature production can't reach (C2); `test_ensemble.R` tests an unreachable method (M1); no test exercises the n>10,000 mini-batch dispatch path (C1 would have been caught by a single such test); no GUI-level test catches H1.

## 10. Reader coverage gaps (declared)

Not fully read by any reader: `06_rules.R`, `13_vulnerability.R` internals, `12_executive_summary.R`, `02a_variable_selection.R`, most of `10_utilities.R` (1,953 lines), `05_profiling.R` beyond the live path, `11_lca.R` lines 353-767, preflight validator bodies, `02_table_builder.R`/`03a_page_styling.R` in full, parked-branch file bodies (characterised from PLAN.md + diff-stat). Claims about these are limited to call-graph facts (grep-verified) — no quality assertion is made about their internals.
